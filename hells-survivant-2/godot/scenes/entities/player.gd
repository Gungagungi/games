class_name Player
extends Node2D
## Héros en calques (paperdoll Dungeon Crawl) : chaque niveau d'épée et
## d'armure acheté à la forge se voit sur lui. Logique de déplacement et de
## combat dans `World`, comme l'objet `player` de la v1.

const SHADER := preload("res://shaders/sprite.gdshader")
const LAYER_ORDER := ["cloak", "base", "boots", "legs", "body", "head", "sword"]
const SPRITE_DIR := "res://assets/sprites/player/"
## Même taille de texel que les monstres ordinaires et le sol ; la hitbox
## (`radius`) reste celle de la v1.
const SCALE := 2.0
const SLASH_COLORS := [
	Color(1, 0.95, 0.85), Color(0.85, 0.8, 0.7), Color(0.9, 0.95, 1),
	Color(0.5, 1, 0.6), Color(1, 0.55, 0.15), Color(0.8, 0.45, 1),
]

var radius := 16.0
var speed := 3.2
var facing := Vector2(0, 1)
var hp := 50.0
var max_hp := 50.0
var attack_timer := 0
var attack_cooldown := 0
var burn_timer := 0
var moving := false
## Projection en cours (`World.knock_player`) : trajet et frames restantes.
var knock_from := Vector2.ZERO
var knock_to := Vector2.ZERO
var knock_time := 1
var knock_timer := 0
## Étourdi (coup de tête du Sbire de l'ombre) : ni déplacement ni coup.
var stun_timer := 0
## Boss qui tient le héros dans sa gueule (Mangeur de soldats), null sinon.
var held_by: Enemy = null

var _rig: Node2D
var _layers := {}
var _mat: ShaderMaterial
var _slash: Slash
var _burn: CPUParticles2D
var _t := 0.0
var _hurt := 0.0
var _dead := 0.0
var _swing_range := 70.0

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	add_child(Fx.light(Color(1.0, 0.8, 0.55), 2.8, 1.0))
	_rig = Node2D.new()
	_rig.material = _mat
	_rig.scale = Vector2.ONE * SCALE
	add_child(_rig)
	for key in LAYER_ORDER:
		var s := Sprite2D.new()
		s.use_parent_material = true
		_rig.add_child(s)
		_layers[key] = s
	_slash = Slash.new()
	_slash.material = Fx.unshaded()
	_slash.z_index = 1
	add_child(_slash)
	_burn = Fx.burn_emitter()
	_burn.emission_sphere_radius = 10.0 * SCALE
	add_child(_burn)
	refresh_equipment()

func refresh_equipment() -> void:
	if _rig == null:
		return
	_set_layer("base", SPRITE_DIR + "base.png")
	for key in ["body", "legs", "boots", "head", "cloak"]:
		_set_layer(key, SPRITE_DIR + "%s_%d.png" % [key, Save.armor_tier])
	_set_layer("sword", SPRITE_DIR + "sword_%d.png" % Save.sword_tier)

func _set_layer(key: String, path: String) -> void:
	var s: Sprite2D = _layers[key]
	s.texture = load(path) if ResourceLoader.exists(path) else null

func start_swing(sword_range: float) -> void:
	_swing_range = sword_range

func hurt() -> void:
	_hurt = 0.18

func die() -> void:
	_dead = 0.001

func revive() -> void:
	_dead = 0.0
	_hurt = 0.0
	_mat.set_shader_parameter("dissolve", 0.0)

func _process(delta: float) -> void:
	_t += delta
	if _dead > 0.0:
		_dead += delta
		_mat.set_shader_parameter("dissolve", clampf(_dead / 0.8, 0.0, 1.0))
		_burn.emitting = false
		_slash.hide_arc()
		return
	if absf(facing.x) > 0.15:
		_rig.scale.x = -SCALE if facing.x < 0.0 else SCALE
	var bob := -absf(sin(_t * 11.0)) * 2.0 * SCALE if moving else 0.0
	var lunge := Vector2.ZERO
	if attack_timer > 0:
		var progress := 1.0 - attack_timer / 14.0
		lunge = facing * 5.0 * SCALE * sin(progress * PI)
		var base_angle := facing.angle()
		_slash.show_arc(base_angle - PI / 3.2, base_angle + (progress - 0.5) * (PI / 1.6),
			_swing_range, SLASH_COLORS[Save.sword_tier], 1.0 - progress * 0.6)
	else:
		_slash.hide_arc()
	_rig.position = Vector2(0, bob) + lunge
	_rig.rotation = sin(_t * 11.0) * 0.05 if moving else 0.0
	# Emporté par la tornade de cendres : il tournoie sur lui-même.
	if held_by != null and is_instance_valid(held_by) and held_by.sp_attack == "tornado_spin":
		_rig.rotation = _t * 18.0
	_hurt = maxf(0.0, _hurt - delta)
	_mat.set_shader_parameter("flash", 0.9 if _hurt > 0.0 else 0.0)
	_burn.emitting = burn_timer > 0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 13.0 * SCALE), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 11.0 * SCALE, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if stun_timer > 0 and _dead == 0.0:
		# Étoiles qui tournent au-dessus de la tête.
		for i in 3:
			var a := _t * 6.0 + TAU * i / 3.0
			_star(Vector2(cos(a) * 14.0, -20.0 * SCALE + sin(a) * 4.0), 5.0, Color(1, 0.9, 0.3))

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * rr)
	draw_colored_polygon(pts, col)

## Croissant de l'estoc : balaie l'arc réellement couvert par le coup.
class Slash extends Node2D:
	var a0 := 0.0
	var a1 := 0.0
	var r := 70.0
	var color := Color.WHITE
	var alpha := 0.0
	var active := false

	func show_arc(from: float, to: float, radius: float, c: Color, a: float) -> void:
		a0 = from
		a1 = to
		r = radius
		color = c
		alpha = a
		active = true
		queue_redraw()

	func hide_arc() -> void:
		if active:
			active = false
			queue_redraw()

	func _draw() -> void:
		if not active or a1 - a0 < 0.05:
			return
		const STEPS := 12
		var pts := PackedVector2Array()
		for i in STEPS + 1:
			pts.append(Vector2.from_angle(lerpf(a0, a1, float(i) / STEPS)) * r)
		for i in range(STEPS, -1, -1):
			var k := float(i) / STEPS
			pts.append(Vector2.from_angle(lerpf(a0, a1, k)) * r * (0.85 - 0.3 * k))
		draw_colored_polygon(pts, Color(color, alpha * 0.55))
		draw_line(Vector2.from_angle(a1) * r * 0.3, Vector2.from_angle(a1) * r, Color(color, alpha), 3.0)
