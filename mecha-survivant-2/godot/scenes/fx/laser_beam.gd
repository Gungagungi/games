class_name LaserBeam
extends Node2D
## Rayon laser de boss : une phase de visée inoffensive (trait fin qui
## s'épaissit), puis un rayon qui frappe le temps de `firing`.
##
## Le rayon part de `source` décalé de `offset` — la visière ou le symbole du
## torse du Destructeur d'univers, par exemple — et suit la source si elle
## bouge. `sweep` (rad/s) fait balayer le rayon pendant qu'il tire : le contact
## est donc testé à chaque image de tir, et ne blesse qu'une fois par rayon.
##
## `length` raccourcit le rayon (l'Esclave du Destructeur vise un point, où il
## explose) ; `follow = false` le fige là où il est né, pour que son extrémité
## reste sur ce point même si la source bouge pendant la charge.
##
## `blast_radius > 0` en fait un rayon **explosif** (visière du Robot géant
## mutant) : pendant la visée, il s'arrête sur le premier mur ; au tir, il
## s'arrête sur le mech s'il est sur sa trajectoire, et explose à ce point
## d'impact — mech ou terrain. Seule l'explosion blesse (`damage`, dans
## `blast_radius`) : un contact du rayon en plus serait de toute façon avalé
## par l'invulnérabilité de coup.

const LENGTH := 1400.0
## Pas de la marche le long du rayon explosif, à la recherche d'un mur.
const WALL_STEP := 8.0
## Demi-largeur du mech ajoutée à celle du rayon pour juger qu'il est touché.
const PLAYER_HALF := 16.0

var source: Node2D
var offset := Vector2.ZERO
var angle := 0.0
var damage := 20.0
var windup := 1.0
var firing := 0.4
var width := 22.0
var sweep := 0.0
var length := LENGTH
var follow := true
var blast_radius := 0.0
var color := Color(1.0, 0.3, 0.3)
var core_color := Color(1.0, 0.85, 0.6)

var _t := 0.0
var _hit := false
var _struck := false
var _max_length := -1.0

func _ready() -> void:
	AudioManager.sfx("laser_charge")
	if source != null and is_instance_valid(source):
		global_position = source.global_position + offset
	if blast_radius > 0.0:
		length = _wall_distance()

func _process(delta: float) -> void:
	if not GameState.running or source == null or not is_instance_valid(source):
		queue_free()
		return
	if follow:
		global_position = source.global_position + offset
		if blast_radius > 0.0:
			length = _wall_distance()
	_t += delta
	queue_redraw()
	if _t < windup:
		return
	if not _struck:
		_struck = true
		EventBus.screen_shake_requested.emit(10.0)
		if blast_radius > 0.0:
			_explode()
	else:
		angle += sweep * delta
	if not _hit and blast_radius <= 0.0:
		_try_hit()
	if _t >= windup + firing:
		queue_free()

func _try_hit() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	var dir := Vector2.RIGHT.rotated(angle)
	var to_player := p.global_position - global_position
	var along := to_player.dot(dir)
	if along < 0.0 or along > length:
		return
	if absf(to_player.cross(dir)) <= width:
		_hit = true
		p.take_damage(damage)

## Distance jusqu'au premier mur ou obstacle dans l'axe du rayon, plafonnée à
## la longueur demandée au départ (`_max_length`). Les boss traversent les
## murs : si la visière part de l'intérieur d'un mur, le rayon en sort d'abord
## et ne s'arrête que sur le suivant.
func _wall_distance() -> float:
	if _max_length < 0.0:
		_max_length = length
	var dir := Vector2.RIGHT.rotated(angle)
	var out := not Level.blocks_projectile(global_position)
	var d := WALL_STEP
	while d < _max_length:
		if Level.blocks_projectile(global_position + dir * d):
			if out:
				return maxf(0.0, d - WALL_STEP * 0.5)
		else:
			out = true
		d += WALL_STEP
	return _max_length

## Point d'impact du rayon explosif : le mech s'il coupe la trajectoire avant
## le mur, sinon le bout du rayon. Le rayon est raccourci jusque-là, l'explosion
## y naît et blesse le mech dans `blast_radius`.
func _explode() -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and p.alive:
		var to_player := p.global_position - global_position
		var along := to_player.dot(dir)
		if along >= 0.0 and along <= length + PLAYER_HALF \
				and absf(to_player.cross(dir)) <= width + PLAYER_HALF:
			length = clampf(along, 0.0, length)
	var at := global_position + dir * length
	Blast.spawn(get_parent(), at, blast_radius, color)
	AudioManager.sfx("shockwave")
	EventBus.screen_shake_requested.emit(12.0)
	_hit = true
	if p != null and p.alive and p.global_position.distance_to(at) <= blast_radius + PLAYER_HALF:
		p.take_damage(damage)

func _draw() -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	if _t < windup:
		var p := _t / windup
		var aim := color
		aim.a = 0.25 + 0.35 * p
		draw_line(Vector2.ZERO, dir * length, aim, 1.0 + 3.0 * p)
		draw_circle(Vector2.ZERO, 4.0 + 6.0 * p, Color(color, 0.5 + 0.5 * p))
	else:
		var fade := 1.0 - (_t - windup) / firing
		draw_line(Vector2.ZERO, dir * length, Color(color, 0.45 * fade), width * 2.6)
		draw_line(Vector2.ZERO, dir * length, Color(core_color, fade), width * 1.4)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 1.0, 1.0, fade), width * 0.5)
		draw_circle(Vector2.ZERO, width * 0.9, Color(core_color, fade))
