class_name LaserBeam
extends Node2D
## Rayon laser de boss : une phase de visée inoffensive (trait fin qui
## s'épaissit), puis un rayon qui frappe le temps de `firing`.
##
## Le rayon part de `source` décalé de `offset` — la visière ou le symbole du
## torse du Destructeur d'univers, par exemple — et suit la source si elle
## bouge. `sweep` (rad/s) fait balayer le rayon pendant qu'il tire : le contact
## est donc testé à chaque image de tir, et ne blesse qu'une fois par rayon.

const LENGTH := 1400.0

var source: Node2D
var offset := Vector2.ZERO
var angle := 0.0
var damage := 20.0
var windup := 1.0
var firing := 0.4
var width := 22.0
var sweep := 0.0
var color := Color(1.0, 0.3, 0.3)
var core_color := Color(1.0, 0.85, 0.6)

var _t := 0.0
var _hit := false
var _struck := false

func _ready() -> void:
	AudioManager.sfx("laser_charge")
	if source != null and is_instance_valid(source):
		global_position = source.global_position + offset

func _process(delta: float) -> void:
	if not GameState.running or source == null or not is_instance_valid(source):
		queue_free()
		return
	global_position = source.global_position + offset
	_t += delta
	queue_redraw()
	if _t < windup:
		return
	if not _struck:
		_struck = true
		EventBus.screen_shake_requested.emit(10.0)
	else:
		angle += sweep * delta
	if not _hit:
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
	if along < 0.0 or along > LENGTH:
		return
	if absf(to_player.cross(dir)) <= width:
		_hit = true
		p.take_damage(damage)

func _draw() -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	if _t < windup:
		var p := _t / windup
		var aim := color
		aim.a = 0.25 + 0.35 * p
		draw_line(Vector2.ZERO, dir * LENGTH, aim, 1.0 + 3.0 * p)
		draw_circle(Vector2.ZERO, 4.0 + 6.0 * p, Color(color, 0.5 + 0.5 * p))
	else:
		var fade := 1.0 - (_t - windup) / firing
		draw_line(Vector2.ZERO, dir * LENGTH, Color(color, 0.45 * fade), width * 2.6)
		draw_line(Vector2.ZERO, dir * LENGTH, Color(core_color, fade), width * 1.4)
		draw_line(Vector2.ZERO, dir * LENGTH, Color(1.0, 1.0, 1.0, fade), width * 0.5)
		draw_circle(Vector2.ZERO, width * 0.9, Color(core_color, fade))
