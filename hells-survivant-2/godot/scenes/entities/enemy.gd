class_name Enemy
extends Node2D
## Monstre ou boss. Les champs reprennent l'objet ennemi de la v1 ; la logique
## (déplacement, tir, charge) vit dans `World`. Ici, uniquement le visuel :
## balancement, flash de coup, télégraphe de charge, aura d'élément, dissolution.

const SHADER := preload("res://shaders/sprite.gdshader")
const DISSOLVE_TIME := 0.5

var radius := 15.0
var hp := 1.0
var max_hp := 1.0
var dmg := 1.0
var speed := 1.0
var element := "sang"
var is_boss := false
var is_final := false
var attack_cooldown := 0
var shoot_cooldown := 60
var hit_flash := 0
var charge_timer := 0.0
var charging := false
var charge_telegraph := 0
var gold_value := 0
var face_left := false

var sprite_scale := 1.0
var glow := Color.WHITE
var _sprite: Sprite2D
var _mat: ShaderMaterial
var _aura: CPUParticles2D
var _light: Fx.Glow
var _t := 0.0
var _dying := 0.0

func _ready() -> void:
	var elem: Dictionary = Data.ELEMENTS[element]
	glow = elem["glow"]
	var key: String = Data.FINAL_BOSS_SPRITE if is_final else (elem["boss_sprite"] if is_boss else elem["sprite"])
	# Texel ×2 comme le héros et le sol ; la hitbox (`radius`) reste celle de la v1.
	sprite_scale = 4.0 if is_final else (3.0 if is_boss else 2.0)
	_t = randf() * TAU
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("outline_color", glow)
	if is_boss or element in ["feu", "ombre", "destruction"]:
		_light = Fx.light(glow, 0.7 * sprite_scale, 0.8)
		add_child(_light)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/monsters/%s.png" % key)
	_sprite.material = _mat
	_sprite.scale = Vector2.ONE * sprite_scale
	add_child(_sprite)
	_aura = Fx.element_aura(element, sprite_scale)
	add_child(_aura)

func top() -> float:
	return 14.0 * sprite_scale

func die() -> void:
	_dying = 0.001
	_aura.emitting = false

func _process(delta: float) -> void:
	_t += delta
	if _dying > 0.0:
		_dying += delta
		_mat.set_shader_parameter("flash", 0.0)
		_mat.set_shader_parameter("dissolve", clampf(_dying / DISSOLVE_TIME, 0.0, 1.0))
		if _light:
			_light.energy = maxf(0.0, _light.energy - delta * 3.0)
		if _dying >= DISSOLVE_TIME:
			queue_free()
		queue_redraw()
		return
	var bob_speed := 7.0 + speed * 2.0
	_sprite.position = Vector2(0, -absf(sin(_t * bob_speed)) * 1.5 * sprite_scale)
	_sprite.rotation = sin(_t * bob_speed) * 0.04
	_sprite.flip_h = face_left
	_mat.set_shader_parameter("flash", 0.85 if hit_flash > 0 else 0.0)
	if charging and charge_telegraph > 0:
		_mat.set_shader_parameter("outline", 0.6 + 0.4 * sin(_t * 30.0))
		_sprite.position.x += randf_range(-1.0, 1.0) * sprite_scale
		_sprite.scale = Vector2.ONE * sprite_scale * (1.0 + 0.06 * sin(_t * 30.0))
		if _light:
			_light.energy = 1.6
	else:
		_mat.set_shader_parameter("outline", 0.45 if is_boss else 0.0)
		_sprite.scale = Vector2.ONE * sprite_scale
		if _light:
			_light.energy = 0.8 + 0.1 * sin(_t * 6.0)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 12.0 * sprite_scale), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 11.0 * sprite_scale, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if _dying > 0.0 or is_boss:
		return
	var w := radius * 2.2
	var y := -top() - 8.0
	draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 6.0), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(-w / 2.0, y, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), glow)
