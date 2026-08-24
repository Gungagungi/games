class_name LaserBeam
extends Node2D
## Laser du Colosse : une phase de visée inoffensive, puis un rayon qui frappe.

const WINDUP := 1.0
const FIRING := 0.4
const LENGTH := 1400.0
const WIDTH := 22.0

var source: Node2D
var angle := 0.0
var damage := 20.0

var _t := 0.0
var _hit := false

func _ready() -> void:
	AudioManager.sfx("laser_charge")

func _process(delta: float) -> void:
	if not GameState.running or source == null or not is_instance_valid(source):
		queue_free()
		return
	global_position = source.global_position
	_t += delta
	queue_redraw()
	if _t >= WINDUP and not _hit:
		_hit = true
		_strike()
	if _t >= WINDUP + FIRING:
		queue_free()

func _strike() -> void:
	EventBus.screen_shake_requested.emit(10.0)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	var dir := Vector2.RIGHT.rotated(angle)
	var to_player := p.global_position - global_position
	var along := to_player.dot(dir)
	if along < 0.0 or along > LENGTH:
		return
	if absf(to_player.cross(dir)) <= WIDTH:
		p.take_damage(damage)

func _draw() -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	if _t < WINDUP:
		var p := _t / WINDUP
		draw_line(Vector2.ZERO, dir * LENGTH, Color(1.0, 0.3, 0.3, 0.25 + 0.3 * p), 2.0)
	else:
		var fade := 1.0 - (_t - WINDUP) / FIRING
		draw_line(Vector2.ZERO, dir * LENGTH, Color(1.0, 0.85, 0.6, fade), WIDTH * 2.0)
		draw_line(Vector2.ZERO, dir * LENGTH, Color(1.0, 1.0, 1.0, fade), WIDTH * 0.6)
