class_name Telegraph
extends Node2D
## Zone d'impact annoncée avant l'effet : un cercle qui se remplit, puis
## `on_fire` est appelé avec la position. Même patron que la v1.

var radius := 120.0
var delay := 0.8
var color := Color(1.0, 0.4, 0.3)
var on_fire: Callable = Callable()

var _t := 0.0
var _fired := false

func _process(delta: float) -> void:
	if not GameState.running:
		return
	_t += delta
	queue_redraw()
	if not _fired and _t >= delay:
		_fired = true
		if on_fire.is_valid():
			on_fire.call(global_position)
	if _t >= delay + 0.25:
		queue_free()

func _draw() -> void:
	var p := clampf(_t / delay, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.7), 3.0)
	draw_circle(Vector2.ZERO, radius * p, Color(color, 0.22))
