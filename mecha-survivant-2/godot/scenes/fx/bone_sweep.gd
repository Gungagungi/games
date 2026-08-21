class_name BoneSweep
extends Node2D
## Balayage d'ossements : un secteur de grand rayon qui tourne autour du boss.
## Phase `windup` d'avertissement inoffensive, puis `duration` actif.

const WINDUP := 1.2
const DURATION := 3.0
const ARC := PI / 3.0
const ROTATION_SPEED := TAU / 4.0

var source: Node2D
var radius := 560.0
var damage := 20.0

var _t := 0.0
var _angle := 0.0
var _hit_cd := 0.0

func _ready() -> void:
	_angle = randf() * TAU
	AudioManager.sfx("bone_sweep")

func _process(delta: float) -> void:
	if not GameState.running or source == null or not is_instance_valid(source):
		queue_free()
		return
	global_position = source.global_position
	_t += delta
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if _t >= WINDUP:
		_angle += ROTATION_SPEED * delta
		_check_hit()
	queue_redraw()
	if _t >= WINDUP + DURATION:
		queue_free()

func _check_hit() -> void:
	if _hit_cd > 0.0:
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	var to_player := p.global_position - global_position
	if to_player.length() > radius:
		return
	var diff := absf(wrapf(to_player.angle() - _angle, -PI, PI))
	if diff <= ARC * 0.5:
		p.take_damage(damage)
		_hit_cd = 0.6

func _draw() -> void:
	var active := _t >= WINDUP
	var col := Color(0.9, 0.88, 0.8, 0.35) if active else Color(0.9, 0.5, 0.4, 0.15)
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 24
	for i in steps + 1:
		var a := _angle - ARC * 0.5 + ARC * float(i) / steps
		points.append(Vector2.RIGHT.rotated(a) * radius)
	draw_colored_polygon(points, col)
