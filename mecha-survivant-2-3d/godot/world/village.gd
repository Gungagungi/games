class_name Village
extends Node3D
## Le niveau : le village en ruine de la v2, régénéré à chaque partie, monté
## en 3D. La **génération est celle de `mecha-survivant-2/godot/scenes/
## level.gd`, case pour case** (rues, place, maisons à portes de deux cases,
## brèches, cimetières, obstacles épars) ; seul le rendu change, confié à
## `village_builder.gd`.
##
## La carte est une grille de `COLS × ROWS` cases de `CELL` mètres, posée sur
## le plan XZ : la case (x, y) couvre x..x+CELL en X et y..y+CELL en Z. Les
## requêtes prennent des positions 2D (x, z) en mètres — le sol est plat, tout
## ce qui compte pour se déplacer se joue au sol.
##
## Ce que le reste du jeu demande :
## - `move_circle()` : glisse un cercle le long des cases pleines (mech et
##   ennemis, comme dans la v2) ;
## - `flow_dir()` : direction vers le mech selon un champ de distances (BFS
##   depuis sa case), un seul calcul pour toute la horde, qui passe ainsi par
##   les portes ;
## - `blocks_point()` / `segment_hit()` : la hauteur compte en 3D — une
##   balle passe au-dessus d'une tombe, pas d'un mur ;
## - `spawn_point()` : une case accessible hors du champ de la caméra.

const CELL := 2.0
const COLS := 112
const ROWS := 64

## Contenu d'une case (mêmes valeurs que la v2).
enum { GROUND, STREET, FLOOR, WALL, BLOCK }
## Nature d'un obstacle (BLOCK) ou d'un décor posé au sol (`_prop`).
enum Prop { NONE = -1, TREE, ROCK, BARREL, GRAVE, STUB, FURNITURE }
const RESERVED := -2   ## seuil de porte : aucun obstacle ici

static var current: Village = null

var _kind := PackedByteArray()
var _variant := PackedByteArray()
var _prop := PackedInt32Array()
var _height := PackedFloat32Array()   ## hauteur de ce qui occupe la case
var _hit_r := PackedFloat32Array()    ## rayon touché par les tirs (0 = case entière)
var _reach := PackedByteArray()
var _dist := PackedInt32Array()
var _flow_origin := Vector2i(-1, -1)
## Second champ, vers une cible quelconque : le pilote automatique s'en sert
## pour aller chercher un ennemi hors de vue.
var _seek_dist := PackedInt32Array()
var _seek_origin := Vector2i(-1, -1)
var _center := Vector2i(COLS >> 1, ROWS >> 1)
var _plaza := Rect2i()
## Lumières du village (lanternes, braseros) : positions, pour le builder.
var light_spots: Array[Vector3] = []

var _visual: Node3D

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

# --- requêtes ------------------------------------------------------------

func world_size() -> Vector2:
	return Vector2(COLS, ROWS) * CELL

## Départ du mech : le centre de la place, toujours dégagée.
func start_position() -> Vector3:
	var p := cell_center(_center)
	return Vector3(p.x, 0.0, p.y)

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))

func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS

func idx(c: Vector2i) -> int:
	return c.y * COLS + c.x

func kind_at(c: Vector2i) -> int:
	return _kind[idx(c)] if inside(c) else WALL

func prop_at(c: Vector2i) -> int:
	return _prop[idx(c)] if inside(c) else Prop.NONE

func variant_at(c: Vector2i) -> int:
	return _variant[idx(c)] if inside(c) else 0

func height_at_cell(c: Vector2i) -> float:
	return _height[idx(c)] if inside(c) else 99.0

func is_solid_cell(c: Vector2i) -> bool:
	if not inside(c):
		return true
	var k := _kind[idx(c)]
	return k == WALL or k == BLOCK

func is_solid_at(pos: Vector2) -> bool:
	return is_solid_cell(cell_of(pos))

func is_reachable(pos: Vector2) -> bool:
	var c := cell_of(pos)
	return inside(c) and _reach[idx(c)] == 1

## Un point de l'espace est-il dans un mur ou un obstacle ? Les murs occupent
## toute leur case jusqu'à leur hauteur ; un obstacle (arbre, tonneau…)
## seulement son rayon de tir, pour qu'on ne bute pas sur l'air autour d'un
## tronc.
func blocks_point(p: Vector3) -> bool:
	if p.y <= 0.0:
		return true
	var c := cell_of(Vector2(p.x, p.z))
	if not is_solid_cell(c):
		return false
	if not inside(c):
		return true
	var i := idx(c)
	if p.y >= _height[i]:
		return false
	var r := _hit_r[i]
	if r <= 0.0:
		return true
	return Vector2(p.x, p.z).distance_squared_to(cell_center(c)) < r * r

## Premier point bloqué sur le segment [a, b], ou `null`. Échantillonné tous
## les `step` mètres : assez fin pour une case de 2 m.
func segment_hit(a: Vector3, b: Vector3, step := 0.3) -> Variant:
	var length := a.distance_to(b)
	var n := maxi(1, ceili(length / step))
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		if blocks_point(p):
			return p
	return null

## Vue dégagée au sol entre deux positions (hauteur d'épaule) : sert aux
## tireurs, qui ne s'arrêtent à portée que s'ils voient le mech.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / (CELL * 0.4)) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		var c := cell_of(p)
		if is_solid_cell(c) and height_at_cell(c) > 1.4:
			return false
	return true

## Déplace un cercle de `motion`, axe par axe, en glissant le long des cases
## pleines (v2 : un axe bloqué est simplement annulé).
func move_circle(pos: Vector2, motion: Vector2, r: float) -> Vector2:
	var out := pos
	var nx := out + Vector2(motion.x, 0.0)
	if not _circle_hits(nx, r):
		out = nx
	var ny := out + Vector2(0.0, motion.y)
	if not _circle_hits(ny, r):
		out = ny
	return out

func _circle_hits(pos: Vector2, r: float) -> bool:
	var a := cell_of(pos - Vector2(r, r))
	var b := cell_of(pos + Vector2(r, r))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var c := Vector2i(x, y)
			if not is_solid_cell(c):
				continue
			var rect := Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))
			var nearest := pos.clamp(rect.position, rect.end)
			if nearest.distance_squared_to(pos) < r * r:
				return true
	return false

## Case libre et accessible la plus proche (spirale autour de `pos`).
func nearest_free(pos: Vector2) -> Vector2:
	var c := cell_of(pos)
	for ring in range(0, 12):
		for y in range(c.y - ring, c.y + ring + 1):
			for x in range(c.x - ring, c.x + ring + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != ring:
					continue
				var cc := Vector2i(x, y)
				if inside(cc) and _reach[idx(cc)] == 1:
					return cell_center(cc) if ring > 0 else pos
	var s := start_position()
	return Vector2(s.x, s.z)

## Une case accessible, à distance du mech et hors du champ de la caméra : les
## ennemis arrivent hors de vue comme dans la v2, où ils naissaient juste
## hors de l'écran. Le radar les montre arriver.
func spawn_point(around: Vector2, cam: Camera3D) -> Vector2:
	var near := 20.0
	var far := 46.0
	for attempt in 80:
		var ang := randf() * TAU
		var d := randf_range(near, far)
		var p := around + Vector2(cos(ang), sin(ang)) * d
		var c := cell_of(p)
		if not inside(c) or _reach[idx(c)] != 1:
			continue
		var at := cell_center(c)
		if cam != null and attempt < 60 and cam.is_position_in_frustum(Vector3(at.x, 1.0, at.y)) \
				and d < 38.0:
			continue
		return at
	for attempt in 400:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		if _reach[idx(c)] == 1 and cell_center(c).distance_to(around) > near:
			return cell_center(c)
	return nearest_free(around)

## Direction à suivre pour rejoindre `target` (le mech) depuis `pos` : tout
## droit en vue directe et de près, sinon vers la case voisine la plus proche
## selon le champ de distances. Reprise de la v2.
func flow_dir(pos: Vector2, target: Vector2) -> Vector2:
	if cell_of(target) != _flow_origin:
		_flow_origin = cell_of(target)
		_bfs(_flow_origin, _dist)
	return _descend(_dist, pos, target)

## Même chose vers une cible quelconque, sur un second champ (pilote auto).
func seek_dir(pos: Vector2, target: Vector2) -> Vector2:
	if cell_of(target) != _seek_origin:
		_seek_origin = cell_of(target)
		_bfs(_seek_origin, _seek_dist)
	return _descend(_seek_dist, pos, target)

func _descend(field: PackedInt32Array, pos: Vector2, target: Vector2) -> Vector2:
	if pos.distance_squared_to(target) < pow(CELL * 6.0, 2) and _line_clear_ground(pos, target):
		return (target - pos).normalized()
	var c := cell_of(pos)
	if not inside(c):
		return (target - pos).normalized()
	var best := field[idx(c)]
	var best_c := c
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n := c + d
		if not inside(n) or field[idx(n)] < 0:
			continue
		if d.x != 0 and d.y != 0 and (is_solid_cell(c + Vector2i(d.x, 0)) \
				or is_solid_cell(c + Vector2i(0, d.y))):
			continue
		if best < 0 or field[idx(n)] < best:
			best = field[idx(n)]
			best_c = n
	if best_c == c:
		return (target - pos).normalized()
	return (cell_center(best_c) - pos).normalized()

func _line_clear_ground(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / (CELL * 0.5)) + 1
	for i in range(1, steps):
		if is_solid_at(a.lerp(b, float(i) / steps)):
			return false
	return true

func _bfs(origin: Vector2i, field: PackedInt32Array) -> void:
	field.fill(-1)
	if not inside(origin):
		return
	var queue := PackedInt32Array()
	queue.resize(COLS * ROWS)
	var head := 0
	var tail := 0
	field[idx(origin)] = 0
	queue[tail] = idx(origin)
	tail += 1
	while head < tail:
		var i := queue[head]
		head += 1
		var x := i % COLS
		@warning_ignore("integer_division")
		var y := i / COLS
		var nd := field[i] + 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
				continue
			var ni := ny * COLS + nx
			if field[ni] >= 0:
				continue
			var k := _kind[ni]
			if k == WALL or k == BLOCK:
				continue
			field[ni] = nd
			queue[tail] = ni
			tail += 1

# --- génération (reprise de la v2) ---------------------------------------

func generate() -> void:
	var n := COLS * ROWS
	_kind.resize(n)
	_kind.fill(GROUND)
	_variant.resize(n)
	_prop.resize(n)
	_prop.fill(Prop.NONE)
	_height.resize(n)
	_height.fill(0.0)
	_hit_r.resize(n)
	_hit_r.fill(0.0)
	_reach.resize(n)
	_dist.resize(n)
	_seek_dist.resize(n)
	_flow_origin = Vector2i(-1, -1)
	_seek_origin = Vector2i(-1, -1)
	for i in n:
		_variant[i] = randi() % 256

	_plaza = Rect2i(_center - Vector2i(6, 4), Vector2i(12, 8))
	var streets := _lay_streets()
	_fill_rect(_plaza, STREET)
	_raise_buildings(streets)
	_lay_graveyards(streets)
	_scatter_obstacles()
	_close_border()
	_compute_reach()
	_assign_heights()
	_place_lights()
	_rebuild_visual()

func _fill_rect(r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if inside(Vector2i(x, y)):
				_kind[y * COLS + x] = kind

## Rues de 3 cases : une trame irrégulière qui découpe la carte en îlots, et
## qui passe toujours par la place. Renvoie les îlots (Rect2i) entre les rues.
func _lay_streets() -> Array[Rect2i]:
	var xs: Array[int] = [_center.x - 1]
	var x := _center.x - 1
	while x > 18:
		x -= randi_range(16, 22)
		xs.push_front(x)
	x = _center.x - 1
	while x < COLS - 18:
		x += randi_range(16, 22)
		xs.push_back(x)
	var ys: Array[int] = [_center.y - 1]
	var y := _center.y - 1
	while y > 14:
		y -= randi_range(13, 17)
		ys.push_front(y)
	y = _center.y - 1
	while y < ROWS - 14:
		y += randi_range(13, 17)
		ys.push_back(y)
	xs = _keep_between(xs, 3, COLS - 6)
	ys = _keep_between(ys, 3, ROWS - 6)
	_street_xs = xs
	_street_ys = ys
	var cut_x: Array[int] = [1]
	cut_x.append_array(ys)
	cut_x.append(ROWS - 1)
	for sx in xs:
		for j in cut_x.size() - 1:
			if sx != _center.x - 1 and randf() < 0.2:
				continue
			_fill_rect(Rect2i(sx, cut_x[j], 3, cut_x[j + 1] - cut_x[j] + 3), STREET)
	var cut_y: Array[int] = [1]
	cut_y.append_array(xs)
	cut_y.append(COLS - 1)
	for sy in ys:
		for i in cut_y.size() - 1:
			if sy != _center.y - 1 and randf() < 0.2:
				continue
			_fill_rect(Rect2i(cut_y[i], sy, cut_y[i + 1] - cut_y[i] + 3, 3), STREET)
	var blocks: Array[Rect2i] = []
	var bx: Array[int] = [-2]
	bx.append_array(xs)
	bx.append(COLS - 1)
	var by: Array[int] = [-2]
	by.append_array(ys)
	by.append(ROWS - 1)
	for j in by.size() - 1:
		for i in bx.size() - 1:
			var r := Rect2i(bx[i] + 3, by[j] + 3, bx[i + 1] - bx[i] - 3, by[j + 1] - by[j] - 3)
			r = r.intersection(Rect2i(2, 2, COLS - 4, ROWS - 4))
			if r.size.x >= 6 and r.size.y >= 6:
				blocks.append(r)
	return blocks

var _street_xs: Array[int] = []
var _street_ys: Array[int] = []

func _keep_between(values: Array[int], lo: int, hi: int) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		if v > lo and v < hi:
			out.append(v)
	return out

## Une ou deux maisons par îlot, murs d'une case, portes de deux cases, puis
## l'usure : des pans tombés (pleins), des brèches (franchissables), du
## mobilier renversé à l'intérieur.
func _raise_buildings(blocks: Array[Rect2i]) -> void:
	blocks.shuffle()
	for b in blocks:
		if randf() < 0.12:
			continue
		var count := 2 if b.size.x >= 15 and randf() < 0.8 else 1
		@warning_ignore("integer_division")
		var slot_w := b.size.x / count
		for k in count:
			if slot_w - 1 < 6 or b.size.y - 1 < 5:
				continue
			for attempt in 4:
				var w := randi_range(6, mini(14, slot_w - 1))
				var h := randi_range(5, mini(10, b.size.y - 1))
				var x0 := b.position.x + k * slot_w + randi_range(0, slot_w - w - 1)
				var y0 := b.position.y + randi_range(0, b.size.y - h - 1)
				var house := Rect2i(x0, y0, w, h)
				if not house.intersects(_plaza.grow(2)):
					_house(house)
					break

func _house(r: Rect2i) -> void:
	var floor_v := randi() % 5
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * COLS + x
			var edge := x == r.position.x or y == r.position.y \
				or x == r.end.x - 1 or y == r.end.y - 1
			_kind[i] = WALL if edge else FLOOR
			_prop[i] = Prop.NONE
			if not edge:
				_variant[i] = floor_v
	_door(r, 2)
	if randf() < 0.6:
		_door(r, randi() % 4)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * COLS + x
			if _kind[i] != WALL:
				continue
			var roll := randf()
			if roll < 0.08:
				_kind[i] = FLOOR
				_variant[i] = floor_v
			elif roll < 0.2:
				_kind[i] = BLOCK
				_prop[i] = Prop.STUB
	for f in randi_range(1, 4):
		var c := Vector2i(randi_range(r.position.x + 1, r.end.x - 2),
			randi_range(r.position.y + 1, r.end.y - 2))
		if _kind[idx(c)] == FLOOR:
			_prop[idx(c)] = Prop.FURNITURE

## side : 0 haut (z−), 1 droite (x+), 2 bas (z+), 3 gauche (x−).
func _door(r: Rect2i, side: int) -> void:
	var horiz := side == 0 or side == 2
	var span := r.size.x if horiz else r.size.y
	var at := randi_range(1, span - 3)
	for k in 2:
		var c: Vector2i
		match side:
			0: c = Vector2i(r.position.x + at + k, r.position.y)
			1: c = Vector2i(r.end.x - 1, r.position.y + at + k)
			2: c = Vector2i(r.position.x + at + k, r.end.y - 1)
			_: c = Vector2i(r.position.x, r.position.y + at + k)
		_kind[idx(c)] = FLOOR
		_variant[idx(c)] = _variant[idx(Vector2i(r.position.x + 1, r.position.y + 1))]
		var outward: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var out: Vector2i = c + outward[side]
		if inside(out):
			_prop[idx(out)] = RESERVED

## Îlots restés vides : pour certains, des cimetières (tombes une case sur
## deux, allées libres entre elles).
func _lay_graveyards(blocks: Array[Rect2i]) -> void:
	var made := 0
	for b in blocks:
		if made >= 3 or not _block_is_empty(b):
			continue
		made += 1
		for y in range(b.position.y + 1, b.end.y - 1, 2):
			for x in range(b.position.x + 1, b.end.x - 1, 2):
				if randf() < 0.75:
					var i := y * COLS + x
					_kind[i] = BLOCK
					_prop[i] = Prop.GRAVE

func _block_is_empty(b: Rect2i) -> bool:
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if _kind[y * COLS + x] != GROUND:
				return false
	return true

## Obstacles épars : arbres morts, rochers, tonneaux. Jamais sur la place,
## jamais devant une porte, jamais collés l'un à l'autre.
func _scatter_obstacles() -> void:
	for attempt in 260:
		var c := Vector2i(randi_range(2, COLS - 3), randi_range(2, ROWS - 3))
		if _plaza.grow(2).has_point(c):
			continue
		var i := idx(c)
		if _kind[i] != GROUND or _prop[i] != Prop.NONE:
			continue
		var crowded := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nb := c + Vector2i(dx, dy)
				var k := _kind[idx(nb)]
				if k == WALL or k == BLOCK or _prop[idx(nb)] == RESERVED:
					crowded = true
		if crowded:
			continue
		var roll := randf()
		_kind[i] = BLOCK
		if roll < 0.45:
			_prop[i] = Prop.TREE
		elif roll < 0.8:
			_prop[i] = Prop.ROCK
		else:
			_prop[i] = Prop.BARREL

func _close_border() -> void:
	for x in COLS:
		_kind[x] = WALL
		_kind[(ROWS - 1) * COLS + x] = WALL
	for y in ROWS:
		_kind[y * COLS] = WALL
		_kind[y * COLS + COLS - 1] = WALL

## Cases libres reliées à la place : seules elles accueillent une apparition.
func _compute_reach() -> void:
	_reach.fill(0)
	_bfs(_center, _dist)
	for i in COLS * ROWS:
		if _dist[i] >= 0:
			_reach[i] = 1
	_flow_origin = Vector2i(-1, -1)

# --- volumes 3D ------------------------------------------------------------

## Hauteur et rayon de tir de chaque case pleine. Les murs de maison sont
## ruinés : hauteur irrégulière d'une case à l'autre, quelques pans plus bas.
## L'enceinte est un rempart haut, qui ferme la vue.
func _assign_heights() -> void:
	for y in ROWS:
		for x in COLS:
			var i := y * COLS + x
			var v := _variant[i]
			match _kind[i]:
				WALL:
					if x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1:
						_height[i] = 6.5 + float(v % 5) * 0.35
					else:
						_height[i] = 2.8 + float(v % 7) * 0.22
						if v % 11 == 0:
							_height[i] = 1.8
				BLOCK:
					match _prop[i]:
						Prop.TREE:
							_height[i] = 6.0
							_hit_r[i] = 0.45
						Prop.ROCK:
							_height[i] = 1.5
							_hit_r[i] = 0.9
						Prop.BARREL:
							_height[i] = 1.25
							_hit_r[i] = 0.75
						Prop.GRAVE:
							_height[i] = 1.15
							_hit_r[i] = 0.55
						_:
							_height[i] = 1.2 + float(v % 4) * 0.2

## Lanternes aux carrefours et braseros autour de la place : la nuit, ce sont
## elles qui éclairent le village. Leur nombre reste modéré — en rendu
## Compatibility, chaque lumière coûte une passe par objet qu'elle touche.
func _place_lights() -> void:
	light_spots.clear()
	for k in 4:
		var corner := Vector2(_plaza.position) + Vector2(_plaza.size) * Vector2(k % 2, k >> 1)
		corner += Vector2(1 if k % 2 == 0 else -1, 1 if k < 2 else -1) * 1.0
		var w := corner * CELL
		light_spots.append(Vector3(w.x, 0.0, w.y))
	for sx in _street_xs:
		for sy in _street_ys:
			var c := Vector2i(sx, sy)
			if _kind[idx(c)] != STREET or _plaza.grow(3).has_point(c):
				continue
			if randf() < 0.55:
				var w := Vector2(c) * CELL + Vector2(0.4, 0.4)
				light_spots.append(Vector3(w.x, 0.0, w.y))

func _rebuild_visual() -> void:
	if _visual != null:
		_visual.queue_free()
	_visual = VillageBuilder.build(self)
	add_child(_visual)
