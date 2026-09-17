class_name Pickup
extends Node2D
## Fiole de soin posée au sol : une par vague, ramassée en marchant dessus.
## Comme les autres entités, elle ne décide de rien — `World` teste la collision
## et applique le soin.

## Même texel ×2 que le héros et les monstres ordinaires.
const SCALE := 2.0

var radius := 18.0
var heal_ratio := 0.2

var _sprite: Sprite2D
var _glow: Fx.Glow
var _t := 0.0

func _ready() -> void:
	_glow = Fx.light(Color(1.0, 0.25, 0.3), 1.6, 0.9)
	add_child(_glow)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/fx/potion.png")
	_sprite.material = Fx.unshaded()
	_sprite.scale = Vector2.ONE * SCALE
	add_child(_sprite)

func _process(delta: float) -> void:
	_t += delta
	# Flottement et pulsation du halo : la fiole doit accrocher l'œil dans
	# l'obscurité de l'arène, même quand la vague bat son plein.
	_sprite.position = Vector2(0, -4.0 - sin(_t * 2.6) * 4.0)
	_glow.energy = 0.75 + 0.25 * sin(_t * 3.4)

func _draw() -> void:
	draw_set_transform(Vector2(0, 10.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0 * SCALE, Color(0, 0, 0, 0.4))
