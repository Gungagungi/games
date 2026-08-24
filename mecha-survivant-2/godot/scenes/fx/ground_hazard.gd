class_name GroundHazard
extends Node2D
## Flaque de poison : blesse tant que le joueur reste dedans.
##
## Avec `hazard_poison.png` déposé, la flaque est cette planche animée mise à
## l'échelle du rayon ; sans, elle reste un disque dessiné à la main.

const SHEET := "hazard_poison"

var radius := 60.0
var lifetime := 6.0
var damage_per_second := 10.0
var color := Color(0.45, 0.85, 0.3)

var _tick := 0.0
var _visual: SpriteOrShape = null

func _ready() -> void:
	var tex := SpriteOrShape.sheet_texture(SHEET)
	if tex == null:
		return
	_visual = SpriteOrShape.new()
	_visual.texture_name = SHEET
	# La planche est cadrée sur le diamètre de la flaque.
	var tile := tex.get_width() / float(SpriteOrShape.sheet_frames(SHEET))
	_visual.scale = Vector2.ONE * (radius * 2.0 / maxf(1.0, tile))
	add_child(_visual)

func _process(delta: float) -> void:
	if not GameState.running:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var fade := clampf(lifetime / 2.0, 0.0, 1.0)
	if _visual != null:
		_visual.modulate = Color(1.0, 1.0, 1.0, fade)
	else:
		queue_redraw()
	_tick -= delta
	if _tick > 0.0:
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and p.alive and p.global_position.distance_to(global_position) <= radius:
		_tick = 0.5
		p.take_damage(damage_per_second * 0.5)

func _draw() -> void:
	var fade := clampf(lifetime / 2.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.22 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(color, 0.6 * fade), 2.0)
