class_name Fx
extends RefCounted
## Effets visuels : lumières, particules d'éléments, textes flottants, or.

static var _light_tex: Texture2D
static var _unshaded: CanvasItemMaterial
static var _additive: CanvasItemMaterial

static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		_light_tex = t
	return _light_tex

## Ignore l'obscurité de l'arène : textes et éclats restent lisibles.
static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded

static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _additive

## Halo additif plutôt que PointLight2D : les lumières 2D ne donnaient aucun
## éclairage visible dans l'export web, un sprite additif s'affiche partout.
## À ajouter avant le sprite de l'entité pour que le halo passe dessous.
static func light(color: Color, size: float, energy := 1.0) -> Glow:
	var g := Glow.new()
	g.texture = light_texture()
	g.material = additive()
	g.self_modulate = Color(color, 1.0)
	g.scale = Vector2.ONE * size
	g.energy = energy
	return g

class Glow extends Sprite2D:
	var energy := 1.0:
		set(v):
			energy = v
			modulate.a = clampf(v * 0.35, 0.0, 1.0)

static func _emitter(amount: int, lifetime: float, from: Color, to: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.local_coords = false
	var ramp := Gradient.new()
	ramp.set_color(0, from)
	ramp.set_color(1, to)
	p.color_ramp = ramp
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.direction = Vector2(0, -1)
	p.material = unshaded()
	return p

static func element_aura(element: String, s: float) -> CPUParticles2D:
	var p: CPUParticles2D
	match element:
		"cendres":
			p = _emitter(8, 1.4, Color(0.85, 0.85, 0.85, 0.7), Color(0.35, 0.35, 0.35, 0))
			p.gravity = Vector2(0, -15)
			p.initial_velocity_max = 8.0
			p.spread = 60.0
		"sang":
			p = _emitter(5, 0.8, Color(0.9, 0.05, 0.1, 1), Color(0.4, 0, 0, 0))
			p.gravity = Vector2(0, 120)
			p.spread = 20.0
		"violence":
			p = _emitter(8, 0.6, Color(1, 0.6, 0.2, 1), Color(1, 0.1, 0, 0))
			p.gravity = Vector2(0, -40)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 30.0
			p.spread = 180.0
		"terre":
			p = _emitter(6, 1.0, Color(0.55, 0.4, 0.25, 0.8), Color(0.3, 0.2, 0.1, 0))
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(10 * s, 2)
			p.position = Vector2(0, 12 * s)
			p.gravity = Vector2(0, -8)
			p.initial_velocity_max = 6.0
			p.spread = 90.0
		"feu":
			p = _emitter(16, 0.9, Color(1, 0.85, 0.3, 1), Color(1, 0.2, 0, 0))
			p.gravity = Vector2(0, -60)
			p.spread = 30.0
		"destruction":
			p = _emitter(10, 0.7, Color(1, 0.2, 0.1, 1), Color(0.15, 0, 0, 0))
			p.gravity = Vector2(0, -30)
			p.initial_velocity_max = 20.0
			p.spread = 180.0
		_:
			p = _emitter(12, 1.2, Color(0.75, 0.4, 1, 0.8), Color(0.2, 0, 0.4, 0))
			p.gravity = Vector2(0, -20)
			p.spread = 45.0
	p.emission_sphere_radius = 9.0 * s
	p.scale_amount_min = 1.0 * s
	p.scale_amount_max = 2.5 * s
	p.amount = maxi(1, int(p.amount * s))
	return p

static func burn_emitter() -> CPUParticles2D:
	var p := _emitter(14, 0.6, Color(1, 0.8, 0.2, 1), Color(1, 0.15, 0, 0))
	p.emission_sphere_radius = 10.0
	p.gravity = Vector2(0, -70)
	p.spread = 25.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.emitting = false
	return p

static func trail(color: Color) -> CPUParticles2D:
	var p := _emitter(12, 0.35, color, Color(color, 0))
	p.emission_sphere_radius = 2.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	return p

static func _burst(parent: Node, pos: Vector2, amount: int, lifetime: float, from: Color, to: Color, speed: float, size: float) -> void:
	var p := _emitter(amount, lifetime, from, to)
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.scale_amount_min = size
	p.scale_amount_max = size * 2.0
	p.position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	parent.add_child(p)

static func puff(parent: Node, pos: Vector2, color: Color, s: float) -> void:
	_burst(parent, pos, int(20 * s), 0.7, color, Color(0.05, 0.05, 0.05, 0), 90.0 * s, 2.0 * s)

static func sparks(parent: Node, pos: Vector2, color: Color) -> void:
	_burst(parent, pos, 8, 0.25, Color.WHITE, Color(color, 0), 140.0, 1.5)

static func float_text(parent: Node, pos: Vector2, text: String, color: Color, big := false) -> void:
	var n := FloatText.new()
	n.text = text
	n.color = color
	n.big = big
	n.position = pos
	parent.add_child(n)

static func gold_pop(parent: Node, pos: Vector2) -> void:
	var n := GoldPop.new()
	n.position = pos
	parent.add_child(n)

## Texte qui monte et s'efface — même durée et vitesse que les particules de la v1.
class FloatText extends Node2D:
	const LIFE := 50.0 / 60.0
	var text := ""
	var color := Color.WHITE
	var big := false
	var _left := LIFE

	func _ready() -> void:
		material = Fx.unshaded()
		var label := Label.new()
		label.use_parent_material = true
		label.text = text
		label.add_theme_font_size_override("font_size", 24 if big else 15)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color(0.08, 0, 0))
		label.add_theme_constant_override("outline_size", 5)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(300, 32)
		label.position = Vector2(-150, -16)
		add_child(label)

	func _process(delta: float) -> void:
		position.y -= 36.0 * delta
		_left -= delta
		modulate.a = clampf(_left / LIFE, 0.0, 1.0)
		if _left <= 0.0:
			queue_free()

class GoldPop extends Node2D:
	const LIFE := 0.7
	var _t := 0.0
	var _sprite: Sprite2D

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://assets/sprites/fx/gold.png")
		_sprite.material = Fx.unshaded()
		_sprite.scale = Vector2(2, 2)
		add_child(_sprite)

	func _process(delta: float) -> void:
		_t += delta
		var k := _t / LIFE
		_sprite.position = Vector2(0, -sin(minf(k, 1.0) * PI) * 22.0)
		_sprite.modulate.a = clampf((1.0 - k) * 3.0, 0.0, 1.0)
		if _t >= LIFE:
			queue_free()
