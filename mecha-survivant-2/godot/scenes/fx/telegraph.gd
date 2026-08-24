class_name Telegraph
extends Node2D
## Zone d'impact annoncée avant l'effet : un cercle qui se remplit, puis
## `on_fire` est appelé avec la position. Même patron que la v1.
##
## Avec `fx_telegraph.png` déposé, le cercle d'annonce est ce sprite mis à
## l'échelle du rayon, dont l'opacité monte avec le remplissage ; sans, il
## reste dessiné à l'arc.

const SHEET := "fx_telegraph"

var radius := 120.0
var delay := 0.8
var color := Color(1.0, 0.4, 0.3)
var on_fire: Callable = Callable()

var _t := 0.0
var _fired := false
var _sprite: Sprite2D = null

func _ready() -> void:
	var tex := SpriteOrShape.sheet_texture(SHEET)
	if tex == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# La planche est cadrée sur le diamètre de la zone annoncée.
	_sprite.scale = Vector2.ONE * (radius * 2.0 / maxf(1.0, tex.get_width()))
	add_child(_sprite)

func _process(delta: float) -> void:
	if not GameState.running:
		return
	_t += delta
	var p := clampf(_t / delay, 0.0, 1.0)
	if _sprite != null:
		_sprite.modulate = Color(color, 0.35 + 0.5 * p)
	else:
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
