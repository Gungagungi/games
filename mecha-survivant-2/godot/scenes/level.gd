class_name Level
extends Node2D
## Le niveau : un village en ruine plus grand que l'écran, régénéré à chaque
## partie. Il porte tout ce qui touche au terrain — rendu, murs, déplacement des
## ennemis — pour que le reste du jeu n'ait qu'à poser des questions simples :
## `is_solid_at()`, `move_circle()`, `flow_dir()`, `view_rect()`.
##
## La carte est une grille de cases de 32 px. Les tuiles viennent des packs
## Kenney (CC0, 16 px affichés ×2, voir `scripts/import-kenney.py`), les pavés
## des rues de `tiles_floor.png`. Sans planche, chaque case retombe sur un aplat.
##
## Collisions :
## - le mech est un `CharacterBody2D` : les murs sont un `StaticBody2D` (couche
##   `WALL_LAYER`), fait de rectangles fusionnés par rangée ;
## - les ennemis sont des `Area2D` déplacés à la main : ils passent par
##   `move_circle()`, qui glisse le long des cases pleines ;
## - les projectiles meurent sur `is_solid_at()` ;
## - les boss traversent tout (choix de conception : des géants dans des ruines).
##
## Les ennemis ne visent pas le mech en ligne droite mais suivent un champ de
## distances (BFS depuis la case du mech, recalculé quand il change de case) :
## un seul calcul pour toute la horde, qui passe ainsi par les portes.

const CELL := 32.0
const COLS := 112
const ROWS := 64
const WALL_LAYER := 16

const TINT := Color.WHITE        ## l'étalonnage est fait à l'import (import-kenney.py)
const STREET_TINT := Color(0.62, 0.62, 0.68)

## Contenu d'une case.
enum { GROUND, STREET, FLOOR, WALL, BLOCK }
## BLOCK : case pleine autre qu'un mur (tombe, arbre mort, rocher, tonneau,
## pan de mur écroulé). Son dessin est dans `_prop`.

# Cases des planches (ordre fixé par scripts/import-kenney.py).
const GROUND_GRASS := [0, 1]
const GROUND_STONY := 2
const GROUND_DIRT := [3, 4]
const WALL_FACES := [0, 1, 2, 3, 4, 5]
const WALL_STUBS := [6, 7]
const PROP_TREES := [0, 1, 2]
const PROP_GRAVES := [3, 4, 5, 6, 7]
const PROP_ROCKS := [8, 9, 10, 11]
const PROP_BARRELS := [12, 13]
const PROP_FURNITURE := [14, 15, 16, 17, 18]
const PROP_STUB_BASE := 100     ## `_prop` ≥ 100 : pan de mur (tiles_wall)

const WALL_TOP := Color(0.36, 0.37, 0.43)
const WALL_EDGE := Color(0.16, 0.16, 0.2)

static var current: Level = null

var _kind := PackedByteArray()
var _variant := PackedByteArray()
var _prop := PackedInt32Array()       ## -1 : rien ; décor sans collision sur sol
var _reach := PackedByteArray()       ## 1 : case libre reliée à la place
var _dist := PackedInt32Array()       ## champ de distances au mech
var _flow_origin := Vector2i(-1, -1)
var _center := Vector2i(COLS >> 1, ROWS >> 1)
var _plaza := Rect2i()
var _walls: StaticBody2D

var _tex_ground: Texture2D
var _tex_indoor: Texture2D
var _tex_wall: Texture2D
var _tex_props: Texture2D
var _tex_street: Texture2D

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

func _ready() -> void:
	_tex_ground = SpriteOrShape.sheet_texture("tiles_ground")
	_tex_indoor = SpriteOrShape.sheet_texture("tiles_indoor")
	_tex_wall = SpriteOrShape.sheet_texture("tiles_wall")
	_tex_props = SpriteOrShape.sheet_texture("tiles_props")
	_tex_street = SpriteOrShape.sheet_texture("tiles_floor")
	generate()

# --- requêtes ------------------------------------------------------------

## Outil de capture (web seulement) : `index.html?apercu-carte` montre toute
## la carte d'un coup, pour juger la génération sans parcourir le niveau.
static func overview_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("location.search", true)).contains("apercu-carte")

func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(COLS, ROWS) * CELL)

## Ce que montre la caméra, en coordonnées du monde.
func view_rect() -> Rect2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()

## Point de départ du mech : le centre de la place, toujours dégagée.
func start_position() -> Vector2:
	return cell_center(_center)

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))

func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL

func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS

func _i(c: Vector2i) -> int:
	return c.y * COLS + c.x

func is_solid_cell(c: Vector2i) -> bool:
	if not _inside(c):
		return true
	var k := _kind[_i(c)]
	return k == WALL or k == BLOCK

func is_solid_at(pos: Vector2) -> bool:
	return is_solid_cell(cell_of(pos))

## Fin de course d'un projectile, quel qu'il soit : un mur, un obstacle, ou le
## bord du monde (hors carte, `is_solid_cell` répond vrai). Sans niveau, rien
## ne l'arrête — sa durée de vie s'en charge.
static func blocks_projectile(pos: Vector2) -> bool:
	return current != null and current.is_solid_at(pos)

## Déplace un cercle de `motion`, axe par axe, en glissant le long des cases
## pleines. Un axe bloqué est simplement annulé : sans rebond ni poussée, ce
## qui suffit à faire longer un mur à un ennemi.
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

## Case libre et accessible la plus proche (spirale autour de `pos`) : pour
## poser une invocation ou un ennemi qui tomberait dans un mur.
func nearest_free(pos: Vector2) -> Vector2:
	var c := cell_of(pos)
	for ring in range(0, 12):
		for y in range(c.y - ring, c.y + ring + 1):
			for x in range(c.x - ring, c.x + ring + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != ring:
					continue
				var cc := Vector2i(x, y)
				if _inside(cc) and _reach[_i(cc)] == 1:
					return cell_center(cc) if ring > 0 else pos
	return start_position()

## Une case libre et accessible juste hors du champ de la caméra : les ennemis
## arrivent par les bords de l'écran comme avant, mais jamais dans un mur.
func spawn_point() -> Vector2:
	var view := view_rect()
	var inner := view.grow(CELL * 1.5)
	var outer := view.grow(CELL * 8.0)
	for attempt in 60:
		var p := Vector2(randf_range(outer.position.x, outer.end.x),
			randf_range(outer.position.y, outer.end.y))
		if inner.has_point(p):
			continue
		var c := cell_of(p)
		if _inside(c) and _reach[_i(c)] == 1:
			return cell_center(c)
	# Tout le pourtour est plein ou hors carte : n'importe quelle case
	# accessible hors champ fera l'affaire.
	for attempt in 400:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		if _reach[_i(c)] == 1 and not inner.has_point(cell_center(c)):
			return cell_center(c)
	return start_position()

## Direction à suivre pour rejoindre le mech depuis `pos`. En vue directe et
## à courte distance, tout droit ; sinon, vers la case voisine la plus proche
## du mech selon le champ de distances.
func flow_dir(pos: Vector2, target: Vector2) -> Vector2:
	_refresh_flow(target)
	if pos.distance_squared_to(target) < pow(CELL * 6.0, 2) and _line_clear(pos, target):
		return (target - pos).normalized()
	var c := cell_of(pos)
	if not _inside(c):
		return (target - pos).normalized()
	var best := _dist[_i(c)]
	var best_c := c
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n := c + d
		if not _inside(n) or _dist[_i(n)] < 0:
			continue
		if d.x != 0 and d.y != 0 and (is_solid_cell(c + Vector2i(d.x, 0)) \
				or is_solid_cell(c + Vector2i(0, d.y))):
			continue
		if best < 0 or _dist[_i(n)] < best:
			best = _dist[_i(n)]
			best_c = n
	if best_c == c:
		return (target - pos).normalized()
	return (cell_center(best_c) - pos).normalized()

func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / (CELL * 0.5)) + 1
	for i in range(1, steps):
		if is_solid_at(a.lerp(b, float(i) / steps)):
			return false
	return true

func _refresh_flow(target: Vector2) -> void:
	var origin := cell_of(target)
	if origin == _flow_origin or not _inside(origin):
		return
	_flow_origin = origin
	_dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(COLS * ROWS)
	var head := 0
	var tail := 0
	_dist[_i(origin)] = 0
	queue[tail] = _i(origin)
	tail += 1
	while head < tail:
		var idx := queue[head]
		head += 1
		var x := idx % COLS
		@warning_ignore("integer_division")
		var y := idx / COLS
		var nd := _dist[idx] + 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
				continue
			var ni := ny * COLS + nx
			if _dist[ni] >= 0:
				continue
			var k := _kind[ni]
			if k == WALL or k == BLOCK:
				continue
			_dist[ni] = nd
			queue[tail] = ni
			tail += 1

# --- génération ----------------------------------------------------------

func generate() -> void:
	var n := COLS * ROWS
	_kind.resize(n)
	_kind.fill(GROUND)
	_variant.resize(n)
	_prop.resize(n)
	_prop.fill(-1)
	_reach.resize(n)
	_dist.resize(n)
	_flow_origin = Vector2i(-1, -1)
	for i in n:
		_variant[i] = randi() % 256

	_plaza = Rect2i(_center - Vector2i(6, 4), Vector2i(12, 8))
	var streets := _lay_streets()
	_fill_rect(_plaza, STREET)
	_scatter_dirt()
	_raise_buildings(streets)
	_lay_graveyards(streets)
	_scatter_obstacles()
	_close_border()
	_compute_reach()
	_rebuild_walls()
	queue_redraw()

func _fill_rect(r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _inside(Vector2i(x, y)):
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
	# Rues tracées tronçon par tronçon (d'un carrefour au suivant), dont un
	# sur cinq manque : la trame reste lisible sans faire damier. Les îlots,
	# eux, restent découpés sur la trame complète.
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

func _keep_between(values: Array[int], lo: int, hi: int) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		if v > lo and v < hi:
			out.append(v)
	return out

## Plaques de terre sur l'herbe, au bruit : un sol uniforme sur 4×4 écrans
## lasse vite l'œil.
func _scatter_dirt() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.08
	for y in ROWS:
		for x in COLS:
			var i := y * COLS + x
			if _kind[i] == GROUND and noise.get_noise_2d(x, y) > 0.25:
				_variant[i] = (_variant[i] & 0xFE) | 1     # bit 0 : terre
			elif _kind[i] == GROUND:
				_variant[i] = _variant[i] & 0xFE

## Une ou deux maisons par îlot, murs d'une case, portes de deux cases, puis
## l'usure : des pans tombés (pleins), des brèches (franchissables), du
## mobilier renversé à l'intérieur.
func _raise_buildings(blocks: Array[Rect2i]) -> void:
	blocks.shuffle()
	for b in blocks:
		if randf() < 0.12:
			continue          # îlot laissé en friche (ou en cimetière, plus bas)
		var count := 2 if b.size.x >= 15 and randf() < 0.8 else 1
		var slot_w := b.size.x / count
		for k in count:
			if slot_w - 1 < 6 or b.size.y - 1 < 5:
				continue
			# Quelques essais : l'îlot peut mordre sur les abords de la place,
			# qui doivent rester dégagés.
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
			_prop[i] = -1
			if not edge:
				_variant[i] = floor_v
	# Portes : une sur le côté bas (face à la caméra, la plus lisible), une
	# autre parfois sur un autre côté. Deux cases de large, jamais en coin.
	_door(r, 2)
	if randf() < 0.6:
		_door(r, randi() % 4)
	# Usure des murs.
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * COLS + x
			if _kind[i] != WALL:
				continue
			var roll := randf()
			if roll < 0.08:
				# Brèche : franchissable, donc sans rocher dessus — un rocher
				# qui ne bloque pas se confondrait avec ceux qui bloquent.
				_kind[i] = FLOOR
				_variant[i] = floor_v
			elif roll < 0.2:
				_kind[i] = BLOCK
				_prop[i] = PROP_STUB_BASE + WALL_STUBS[randi() % WALL_STUBS.size()]
	# Mobilier renversé : décor sans collision.
	for f in randi_range(1, 4):
		var c := Vector2i(randi_range(r.position.x + 1, r.end.x - 2),
			randi_range(r.position.y + 1, r.end.y - 2))
		if _kind[_i(c)] == FLOOR:
			_prop[_i(c)] = PROP_FURNITURE[randi() % PROP_FURNITURE.size()]

## side : 0 haut, 1 droite, 2 bas, 3 gauche.
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
		_kind[_i(c)] = FLOOR
		_variant[_i(c)] = _variant[_i(Vector2i(r.position.x + 1, r.position.y + 1))]
		# Le seuil, dehors, reste dégagé : un obstacle posé devant murerait la
		# porte.
		var outward: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var out: Vector2i = c + outward[side]
		if _inside(out):
			_prop[_i(out)] = -2      # réservé : aucun obstacle ici

## Les îlots restés vides deviennent, pour certains, des cimetières : tombes
## pleines alignées une case sur deux, allées libres entre elles.
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
					_prop[i] = PROP_GRAVES[randi() % PROP_GRAVES.size()]

func _block_is_empty(b: Rect2i) -> bool:
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if _kind[y * COLS + x] != GROUND:
				return false
	return true

## Obstacles épars dehors : arbres morts, rochers, tonneaux. Jamais sur la
## place, jamais devant une porte, jamais collés l'un à l'autre — un couloir
## d'une case bloquerait la horde.
func _scatter_obstacles() -> void:
	for attempt in 260:
		var c := Vector2i(randi_range(2, COLS - 3), randi_range(2, ROWS - 3))
		if _plaza.grow(2).has_point(c):
			continue
		var i := _i(c)
		if _kind[i] != GROUND or _prop[i] != -1:
			continue
		var crowded := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if _kind[_i(n)] == WALL or _kind[_i(n)] == BLOCK or _prop[_i(n)] == -2:
					crowded = true
		if crowded:
			continue
		var roll := randf()
		_kind[i] = BLOCK
		if roll < 0.45:
			_prop[i] = PROP_TREES[randi() % PROP_TREES.size()]
		elif roll < 0.8:
			_prop[i] = PROP_ROCKS[randi() % PROP_ROCKS.size()]
		else:
			_prop[i] = PROP_BARRELS[randi() % PROP_BARRELS.size()]

func _close_border() -> void:
	for x in COLS:
		_kind[x] = WALL
		_kind[(ROWS - 1) * COLS + x] = WALL
	for y in ROWS:
		_kind[y * COLS] = WALL
		_kind[y * COLS + COLS - 1] = WALL

## Cases libres reliées à la place. Une case libre isolée (cour murée par des
## pans tombés) n'accueille ni apparition ni invocation, et le champ de
## distances ne l'atteint pas.
func _compute_reach() -> void:
	_reach.fill(0)
	_refresh_flow(start_position())
	for i in COLS * ROWS:
		if _dist[i] >= 0:
			_reach[i] = 1
	_flow_origin = Vector2i(-1, -1)

## Un StaticBody2D, un rectangle par suite horizontale de cases pleines : une
## soixantaine de formes au lieu de plusieurs centaines.
func _rebuild_walls() -> void:
	if _walls != null:
		_walls.queue_free()
	_walls = StaticBody2D.new()
	_walls.collision_layer = WALL_LAYER
	_walls.collision_mask = 0
	for y in ROWS:
		var x := 0
		while x < COLS:
			if not is_solid_cell(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while x < COLS and is_solid_cell(Vector2i(x, y)):
				x += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((x - start) * CELL, CELL)
			shape.shape = rect
			shape.position = Vector2((start + x) * 0.5 * CELL, (y + 0.5) * CELL)
			_walls.add_child(shape)
	add_child(_walls)

# --- rendu ---------------------------------------------------------------

## Tout le niveau d'un coup : Godot garde les commandes de dessin tant que
## `queue_redraw()` n'est pas rappelé, soit une fois par partie.
func _draw() -> void:
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			var i := y * COLS + x
			var rect := Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))
			match _kind[i]:
				STREET:
					_draw_street(rect, c)
				FLOOR:
					_tile(_tex_indoor, 5, _variant[i] % 5, rect, Color(0.42, 0.34, 0.26))
				WALL:
					_draw_wall(rect, c, i)
				_:
					_draw_ground(rect, i)
			if _kind[i] == BLOCK and _prop[i] >= PROP_STUB_BASE:
				_tile(_tex_wall, 8, _prop[i] - PROP_STUB_BASE, rect, WALL_TOP)
			elif _prop[i] >= 0:
				_tile(_tex_props, 19, _prop[i], rect, Color(0.3, 0.28, 0.26))

func _draw_ground(rect: Rect2, i: int) -> void:
	var v := _variant[i]
	var frame: int
	if v & 1:
		frame = GROUND_DIRT[(v >> 1) % 2]
	elif (v >> 1) % 9 == 0:
		frame = GROUND_STONY
	else:
		frame = GROUND_GRASS[(v >> 1) % 2]
	_tile(_tex_ground, 7, frame, rect, Color(0.2, 0.26, 0.18))

func _draw_street(rect: Rect2, c: Vector2i) -> void:
	if _tex_street == null:
		draw_rect(rect, Color(0.2, 0.22, 0.28))
		return
	var variants := SpriteOrShape.sheet_frames("tiles_floor")
	var w := _tex_street.get_width() / float(variants)
	var v := absi(hash(c)) % variants
	draw_texture_rect_region(_tex_street, rect,
		Rect2(v * w, 0.0, w, _tex_street.get_height()), STREET_TINT)

## Vue de trois quarts à peu de frais : une case de mur dont la voisine du
## dessous n'est pas un mur montre sa face (tuile Kenney) ; les autres montrent
## le dessus, un aplat cerné là où le mur s'arrête.
func _draw_wall(rect: Rect2, c: Vector2i, i: int) -> void:
	if not _is_wall(c + Vector2i(0, 1)):
		_tile(_tex_wall, 8, WALL_FACES[_variant[i] % WALL_FACES.size()], rect, WALL_TOP)
		draw_rect(Rect2(rect.position, Vector2(CELL, 3.0)), WALL_EDGE)
		return
	draw_rect(rect, WALL_TOP.darkened(0.15))
	if not _is_wall(c + Vector2i(-1, 0)):
		draw_rect(Rect2(rect.position, Vector2(3.0, CELL)), WALL_EDGE)
	if not _is_wall(c + Vector2i(1, 0)):
		draw_rect(Rect2(rect.position + Vector2(CELL - 3.0, 0.0), Vector2(3.0, CELL)), WALL_EDGE)
	if not _is_wall(c + Vector2i(0, -1)):
		draw_rect(Rect2(rect.position, Vector2(CELL, 3.0)), WALL_EDGE)

func _is_wall(c: Vector2i) -> bool:
	return _inside(c) and _kind[_i(c)] == WALL

## Une case de planche, teintée ; sans planche, l'aplat de secours.
func _tile(tex: Texture2D, frames: int, frame: int, rect: Rect2, fallback: Color) -> void:
	if tex == null:
		draw_rect(rect, fallback)
		return
	var w := tex.get_width() / float(frames)
	draw_texture_rect_region(tex, rect, Rect2(frame * w, 0.0, w, tex.get_height()), TINT)
