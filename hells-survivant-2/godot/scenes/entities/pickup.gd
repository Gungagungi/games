class_name Pickup
extends Node2D
## Objet posé au sol, ramassé en marchant dessus : la fiole de soin (une par
## vague) ou l'Œil corrompu, que lâche la Créature cauchemardesque à sa mort et
## qui tombe du ciel. Comme les autres entités, il ne décide de rien — `World`
## teste la collision et applique l'effet.

## Même texel ×2 que le héros et les monstres ordinaires.
const SCALE := 2.0
## Chute de l'Œil corrompu : hauteur de départ et durée, en secondes.
const EYE_DROP := 320.0
const EYE_FALL := 0.9

## "potion" | "eye"
var kind := "potion"
var radius := 18.0
var heal_ratio := 0.2

var _sprite: Sprite2D
var _glow: Fx.Glow
var _t := 0.0

func _ready() -> void:
	var is_eye := kind == "eye"
	_glow = Fx.light(Data.CORRUPT_COLOR if is_eye else Color(1.0, 0.25, 0.3), 2.4 if is_eye else 1.6, 0.9)
	add_child(_glow)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/fx/%s.png" % ("corrupted_eye" if is_eye else "potion"))
	_sprite.material = Fx.unshaded()
	# L'Œil est découpé dans le sprite de la Créature (`unseen_horror`) et
	# agrandi ×2 dans le fichier : à l'écran, il a la taille de l'œil du boss.
	_sprite.scale = Vector2.ONE * SCALE
	add_child(_sprite)

## L'Œil ne se ramasse qu'une fois au sol.
func landed() -> bool:
	return kind != "eye" or _t >= EYE_FALL

func _process(delta: float) -> void:
	_t += delta
	# Flottement et pulsation du halo : l'objet doit accrocher l'œil dans
	# l'obscurité de l'arène, même quand la vague bat son plein.
	var lift := 0.0
	if kind == "eye" and _t < EYE_FALL:
		var f := _t / EYE_FALL
		lift = EYE_DROP * (1.0 - f * f)
		_sprite.rotation = (1.0 - f) * TAU * 1.5
	else:
		_sprite.rotation = 0.0
	_sprite.position = Vector2(0, -4.0 - sin(_t * 2.6) * 4.0 - lift)
	_glow.position = Vector2(0, -lift)
	_glow.energy = 0.75 + 0.25 * sin(_t * 3.4)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 10.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0 * SCALE, Color(0, 0, 0, 0.4))
	if kind == "eye" and _t >= EYE_FALL:
		# Cercle corrompu au sol, qui signale l'Œil à ramasser.
		draw_arc(Vector2.ZERO, 16.0 * SCALE + 3.0 * sin(_t * 4.0), 0.0, TAU, 40, Color(Data.CORRUPT_COLOR, 0.7), 3.0)
