class_name HitSpark
extends Node2D
## Impact joué à chaque coup encaissé par un ennemi.
##
## Purement décoratif, et purement optionnel : sans `fx_hit.png` déposé, rien
## n'est instancié et le seul retour visuel reste le `flash()` du sprite touché,
## comme avant. Voir `assets/MANIFEST.md`.

const SHEET := "fx_hit"
const FPS := 24.0

## Instancie l'impact dans `parent`, ou ne fait rien si l'asset est absent.
static func spawn(parent: Node, at: Vector2, tint: Color = Color.WHITE) -> void:
	var tex := SpriteOrShape.sheet_texture(SHEET)
	if tex == null or parent == null:
		return
	var fx := HitSpark.new()
	fx.position = at
	fx.modulate = tint
	fx._texture = tex
	parent.add_child(fx)

var _texture: Texture2D = null
var _sprite: Sprite2D
var _t := 0.0

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _texture
	_sprite.hframes = SpriteOrShape.sheet_frames(SHEET)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

func _process(delta: float) -> void:
	_t += delta
	var frame := int(_t * FPS)
	if frame >= _sprite.hframes:
		queue_free()
		return
	_sprite.frame = frame
