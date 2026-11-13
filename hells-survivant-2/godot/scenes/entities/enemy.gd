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
## Double de la Créature cauchemardesque (voir `Nightmare`) : mêmes attaques,
## sauf le laser, l'invocation et le dédoublement.
var is_clone := false
## Mini-créature invoquée par la Créature : monstre de mêlée ordinaire.
var is_mini := false

# État des attaques de la Créature cauchemardesque, piloté par `Nightmare`.
## Attaque en cours ("" : elle marche sur le héros) et frames restantes.
var nm_attack := ""
var nm_timer := 0
var nm_cooldown := 120
var nm_last := ""
var nm_hit := false
var nm_dir := Vector2.RIGHT
var nm_lash: Array[Vector2] = []
var nm_from := Vector2.ZERO
var nm_target := Vector2.ZERO
## Hauteur du saut : décale le sprite, pas la position au sol.
var nm_height := 0.0
var nm_splits := 0
var nm_slide := Vector2.ZERO
var nm_slide_timer := 0

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
	var key: String = Data.final_boss(element)["sprite"] if is_final else (elem["boss_sprite"] if is_boss else elem["sprite"])
	# Texel ×2 comme le héros et le sol ; la hitbox (`radius`) reste celle de la v1.
	sprite_scale = 4.0 if is_final else (3.0 if is_boss or is_clone else 2.0)
	_t = randf() * TAU
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("outline_color", glow)
	if is_boss or is_clone or element in ["feu", "ombre", "destruction"]:
		_light = Fx.light(glow, 0.7 * sprite_scale, 0.8)
		add_child(_light)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/monsters/%s.png" % key)
	_sprite.material = _mat
	_sprite.scale = Vector2.ONE * sprite_scale
	add_child(_sprite)
	if is_clone:
		# Double un peu spectral, pour le distinguer de l'original.
		_sprite.modulate = Color(0.8, 0.75, 1.0, 0.78)
	_aura = Fx.element_aura(element, sprite_scale)
	add_child(_aura)
	if Nightmare.handles(self):
		var body := NightmareFx.new()
		body.enemy = self
		body.material = Fx.unshaded()
		body.z_index = 5
		add_child(body)
		var beam := NightmareFx.new()
		beam.enemy = self
		beam.beam = true
		beam.material = Fx.additive()
		beam.z_index = 6
		add_child(beam)

func top() -> float:
	return 14.0 * sprite_scale

## Œil de la Créature cauchemardesque, d'où part le laser (coordonnées de
## l'arène). Repéré sur le sprite 32×32 : texel (13,5 ; 11), soit 2,5 à gauche
## et 5 au-dessus du centre, en miroir quand le sprite est retourné.
func eye_position() -> Vector2:
	return position + eye_offset()

func eye_offset() -> Vector2:
	return Vector2(2.5 if face_left else -2.5, -5.0) * sprite_scale - Vector2(0, nm_height)

## Base des tentacules, sous le corps (coordonnées locales).
func tentacle_root() -> Vector2:
	return Vector2(0, 5.0 * sprite_scale - nm_height)

func die() -> void:
	_dying = 0.001
	nm_attack = ""
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
	if nm_height > 0.0:
		_sprite.position.y -= nm_height
	elif nm_attack == "jump_crouch":
		# Accroupie avant le saut : écrasée et tremblante.
		_sprite.scale = Vector2(1.1, 0.88) * sprite_scale
	elif nm_attack in ["split", "summon", "field_aim"]:
		_sprite.position.x += randf_range(-1.5, 1.5) * sprite_scale
	_mat.set_shader_parameter("flash", 0.85 if hit_flash > 0 else 0.0)
	if charging and charge_telegraph > 0:
		_mat.set_shader_parameter("outline", 0.6 + 0.4 * sin(_t * 30.0))
		_sprite.position.x += randf_range(-1.0, 1.0) * sprite_scale
		_sprite.scale = Vector2.ONE * sprite_scale * (1.0 + 0.06 * sin(_t * 30.0))
		if _light:
			_light.energy = 1.6
	elif nm_attack in ["split", "summon", "laser_aim", "laser", "field_aim"]:
		_mat.set_shader_parameter("outline", 0.6 + 0.4 * sin(_t * 24.0))
		_sprite.scale = Vector2.ONE * sprite_scale
		if _light:
			_light.energy = 1.4
	else:
		_mat.set_shader_parameter("outline", 0.45 if is_boss or is_clone else 0.0)
		if nm_attack != "jump_crouch":
			_sprite.scale = Vector2.ONE * sprite_scale
		if _light:
			_light.energy = 0.8 + 0.1 * sin(_t * 6.0)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 12.0 * sprite_scale), 0.0, Vector2(1.0, 0.35))
	# En saut, l'ombre reste au sol et rétrécit avec la hauteur.
	var lift := clampf(1.0 - nm_height / 220.0, 0.4, 1.0)
	draw_circle(Vector2.ZERO, 11.0 * sprite_scale * lift, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if _dying > 0.0 or is_boss:
		return
	var w := radius * 2.2
	var y := -top() - 8.0
	draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 6.0), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(-w / 2.0, y, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), glow)

## Visuel des attaques de la Créature cauchemardesque. Deux instances par
## créature : tentacules et télégraphes en mélange normal (le violet sombre
## disparaîtrait en additif), laser et onde de choc en additif.
class NightmareFx extends Node2D:
	const BODY := Color(0.32, 0.05, 0.38)
	const RIM := Color(0.95, 0.3, 0.8)
	const BEAM := Color(1.0, 0.25, 0.75)
	var enemy: Enemy
	var beam := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var e := enemy
		if e._dying > 0.0:
			return
		var k := float(e.nm_timer)
		if beam:
			_draw_beam(e, k)
			return
		var root := e.tentacle_root()
		match e.nm_attack:
			"lash_aim":
				var a := 0.25 + 0.35 * absf(sin(_t * 18.0))
				for d: Vector2 in e.nm_lash:
					_dashed(root, root + d * Nightmare.LASH_LEN, Color(RIM, a), 3.0)
			"lash":
				var reach := Nightmare.lash_reach(e)
				for d: Vector2 in e.nm_lash:
					_tentacle(root, d, reach, 16.0, _t * 14.0)
			"sweep_aim":
				var f := 1.0 - k / Nightmare.SWEEP_AIM
				draw_circle(root, Nightmare.SWEEP_R * f, Color(RIM, 0.18))
				draw_arc(root, Nightmare.SWEEP_R, 0.0, TAU, 48, Color(RIM, 0.5 + 0.4 * sin(_t * 30.0)), 3.0)
			"sweep":
				var f := 1.0 - k / Nightmare.SWEEP_TIME
				for i in 8:
					var d := Vector2.from_angle(TAU * i / 8.0 + f * 2.5)
					_tentacle(root, d, Nightmare.SWEEP_R * sin(f * PI), 14.0, _t * 18.0 + i)
			"jump":
				# Point d'impact : là où l'onde partira.
				var target := e.nm_target - e.position
				var f := 1.0 - k / Nightmare.JUMP_AIR
				draw_arc(target, Nightmare.WAVE_R * 0.25, 0.0, TAU, 40, Color(RIM, 0.3 + 0.5 * f), 3.0)
				draw_circle(target, 26.0 + 30.0 * f, Color(RIM, 0.15 + 0.2 * f))

	func _draw_beam(e: Enemy, k: float) -> void:
		var eye := e.eye_offset()
		match e.nm_attack:
			"laser_aim":
				var locked := k <= Nightmare.LASER_LOCK
				var a := (0.9 if int(_t * 20.0) % 2 == 0 else 0.4) if locked else 0.35
				draw_line(eye, eye + e.nm_dir * Nightmare.LASER_LEN, Color(BEAM, a), 3.0 if locked else 1.5)
				draw_circle(eye, 6.0 + 10.0 * (1.0 - k / Nightmare.LASER_AIM), Color(BEAM, 0.8))
			"laser":
				var end := eye + e.nm_dir * Nightmare.LASER_LEN
				var pulse := 1.0 + 0.15 * sin(_t * 50.0)
				# Ouverture puis extinction du rayon sur quelques frames.
				var open := clampf(minf(Nightmare.LASER_FIRE - k, k) / 6.0, 0.0, 1.0)
				draw_line(eye, end, Color(BEAM, 0.35), 46.0 * pulse * open)
				draw_line(eye, end, Color(BEAM, 0.8), 26.0 * pulse * open)
				draw_line(eye, end, Color(1, 0.9, 1, 1), 9.0 * open)
				draw_circle(eye, 22.0 * pulse * open, Color(BEAM, 0.9))
				draw_circle(eye, 10.0 * open, Color.WHITE)
			"field_aim":
				# La sphère gonfle jusqu'à sa taille finale, de plus en plus vive.
				var f := 1.0 - k / Nightmare.FIELD_AIM
				var c := Vector2(0, -4.0 * e.sprite_scale)
				var pulse := 0.5 + 0.5 * sin(_t * (12.0 + 30.0 * f))
				draw_circle(c, Nightmare.FIELD_R * f, Color(BEAM, 0.08 + 0.12 * f))
				draw_arc(c, Nightmare.FIELD_R * f, 0.0, TAU, 64, Color(1, 0.85, 1, 0.3 + 0.5 * f), 3.0)
				# Limite de la zone touchée, dès le début : le temps de sortir.
				draw_arc(c, Nightmare.FIELD_R, 0.0, TAU, 64, Color(BEAM, 0.25 + 0.35 * pulse), 2.0)
			"field":
				var f := 1.0 - k / Nightmare.FIELD_TIME
				var c := Vector2(0, -4.0 * e.sprite_scale)
				var r := Nightmare.FIELD_R * (1.0 + 0.25 * f)
				draw_circle(c, r, Color(BEAM, 0.35 * (1.0 - f)))
				draw_arc(c, r, 0.0, TAU, 64, Color(BEAM, 0.8 * (1.0 - f)), 18.0 * (1.0 - f) + 2.0)
				draw_arc(c, r, 0.0, TAU, 64, Color(1, 0.9, 1, 1.0 - f), 4.0)
			"shockwave":
				var r := Nightmare.wave_radius(e)
				var a := k / Nightmare.WAVE_TIME
				var c := Vector2(0, 6.0 * e.sprite_scale)
				draw_arc(c, r, 0.0, TAU, 64, Color(BEAM, 0.35 * a + 0.2), Nightmare.WAVE_HALF * 2.2)
				draw_arc(c, r, 0.0, TAU, 64, Color(1, 0.85, 1, a), 4.0)

	## Tentacule ondulé et effilé, de `from` sur `length` selon `dir`.
	func _tentacle(from: Vector2, dir: Vector2, length: float, width: float, phase: float) -> void:
		if length < 2.0:
			return
		const N := 14
		var normal := dir.orthogonal()
		var pts := PackedVector2Array()
		for i in N + 1:
			var f := float(i) / N
			pts.append(from + dir * length * f + normal * sin(f * 9.0 - phase) * 9.0 * f)
		for pass_rim in [true, false]:
			for i in N:
				var w := width * (1.0 - 0.8 * float(i) / N)
				var col := RIM if pass_rim else BODY
				var ww := w + 4.0 if pass_rim else w
				draw_line(pts[i], pts[i + 1], col, ww)
				draw_circle(pts[i + 1], ww / 2.0, col)
		draw_circle(pts[N], width * 0.35, RIM)

	func _dashed(a: Vector2, b: Vector2, col: Color, width: float) -> void:
		var n := int(a.distance_to(b) / 18.0)
		for i in range(0, n, 2):
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, width)
