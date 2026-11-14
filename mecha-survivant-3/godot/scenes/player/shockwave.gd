class_name Shockwave
extends Node2D
## Anneau de l'onde de choc. Purement visuel : les dégâts sont appliqués
## d'un coup par le joueur au déclenchement.
##
## Avec `fx_shockwave.png` déposé, l'anneau est la planche animée mise à
## l'échelle du rayon ; sans, il reste dessiné à l'arc comme dans la v1.

const SHEET := "fx_shockwave"
const DURATION := 0.35

var max_radius := 140.0
var _t := 0.0
var _sprite: Sprite2D = null

func _ready() -> void:
	var tex := SpriteOrShape.sheet_texture(SHEET)
	if tex == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = SpriteOrShape.sheet_frames(SHEET)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	if _sprite == null:
		queue_redraw()
		return
	var p := _t / DURATION
	# La planche est cadrée sur le diamètre : une case couvre 2 * max_radius.
	var tile := Vector2(_sprite.texture.get_width() / float(_sprite.hframes),
		_sprite.texture.get_height())
	_sprite.scale = Vector2.ONE * (max_radius * 2.0 / maxf(1.0, tile.x)) * ease(p, 0.4)
	_sprite.frame = mini(int(p * _sprite.hframes), _sprite.hframes - 1)
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - p)

func _draw() -> void:
	var p := _t / DURATION
	var r := max_radius * ease(p, 0.4)
	var alpha := 1.0 - p
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.45, 0.85, 1.0, alpha), 6.0)
	draw_arc(Vector2.ZERO, r * 0.75, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, alpha * 0.5), 3.0)
