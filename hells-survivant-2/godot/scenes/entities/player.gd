class_name Player
extends Node2D
## Héros en calques (paperdoll Dungeon Crawl) : chaque niveau d'épée et
## d'armure acheté à la forge se voit sur lui. Logique de déplacement et de
## combat dans `World`, comme l'objet `player` de la v1.

const SHADER := preload("res://shaders/sprite.gdshader")
const LAYER_ORDER := ["cloak", "base", "boots", "legs", "body", "head", "sword"]
const ARMOR_LAYERS := ["body", "legs", "boots", "head", "cloak"]
const CORRUPT_DARK := Color(0.16, 0.03, 0.26)
const CORRUPT_LIGHT := Color(0.86, 0.58, 1.0)
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
var _armor_spikes: Spikes
var _sword_spikes: Spikes
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
	# Pics de l'armure sous tous les calques, ceux de l'épée juste sous sa
	# lame : leur base se cache sous le sprite, ils en sortent.
	_armor_spikes = Spikes.new()
	_armor_spikes.use_parent_material = true
	_rig.add_child(_armor_spikes)
	for key in LAYER_ORDER:
		if key == "sword":
			_sword_spikes = Spikes.new()
			_sword_spikes.use_parent_material = true
			_rig.add_child(_sword_spikes)
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
	# Sans armure (« Peau nue Corrompue »), c'est la peau qui se corrompt.
	var armor_keys: Array = ARMOR_LAYERS.filter(func(k: String) -> bool: return _layers[k].texture != null)
	if armor_keys.is_empty():
		armor_keys = ["base"]
	for key in LAYER_ORDER:
		var corrupt: bool = (key == "sword" and Save.sword_corrupt) \
			or (Save.armor_corrupt and armor_keys.has(key))
		if corrupt:
			var s: Sprite2D = _layers[key]
			s.texture = _corrupted(s.texture)
	var body_keys: Array = LAYER_ORDER.filter(func(k: String) -> bool: return k != "sword")
	_armor_spikes.set_spikes(_spike_points(armor_keys, body_keys, 5.0, 12, 3.5, 6.0, 11)
		if Save.armor_corrupt else [])
	_sword_spikes.set_spikes(_spike_points(["sword"], LAYER_ORDER, 3.0, 8, 2.5, 4.5, 23)
		if Save.sword_corrupt and _layers["sword"].texture != null else [])

func _set_layer(key: String, path: String) -> void:
	var s: Sprite2D = _layers[key]
	s.texture = load(path) if ResourceLoader.exists(path) else null

## Calque enchanté par l'Œil corrompu, repeint en violet d'après sa
## luminance. Fait sur l'image plutôt que par un second matériau : dans
## l'export web, un matériau propre à certains calques du `_rig` ne
## s'appliquait qu'à une partie d'entre eux. Mis en cache par fichier.
static var _corrupt_cache := {}

static func _corrupted(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _corrupt_cache.has(tex.resource_path):
		return _corrupt_cache[tex.resource_path]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var l := smoothstep(0.05, 0.85, c.get_luminance())
			var v := CORRUPT_DARK.lerp(CORRUPT_LIGHT, l)
			img.set_pixel(x, y, Color(v, c.a))
	var out := ImageTexture.create_from_image(img)
	_corrupt_cache[tex.resource_path] = out
	return out

func _set_param(param: String, value: Variant) -> void:
	_mat.set_shader_parameter(param, value)

## Pics le long du contour des calques `src`, pointés vers l'extérieur de la
## silhouette formée par `solid` (un pic ne rentre pas dans le corps). En
## texels du sprite, centré comme un `Sprite2D`. Tirage fixe (`rng_seed`) : les pics
## ne bougent pas d'une partie à l'autre.
func _spike_points(src: Array, solid: Array, spacing: float, max_count: int,
		len_min: float, len_max: float, rng_seed: int) -> Array:
	var size := Vector2i(32, 32)
	var src_img: Array[Image] = []
	var solid_img: Array[Image] = []
	for key: String in solid:
		var tex: Texture2D = _layers[key].texture
		if tex == null:
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		size = img.get_size()
		solid_img.append(img)
		if src.has(key):
			src_img.append(img)
	var opaque := func(imgs: Array[Image], x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= size.x or y >= size.y:
			return false
		for img in imgs:
			if img.get_pixel(x, y).a > 0.5:
				return true
		return false
	var candidates: Array = []
	for y in size.y:
		for x in size.x:
			if not opaque.call(src_img, x, y):
				continue
			var n := Vector2.ZERO
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if (dx != 0 or dy != 0) and not opaque.call(solid_img, x + dx, y + dy):
						n += Vector2(dx, dy).normalized()
			if n.length() > 0.9:
				candidates.append([Vector2(x + 0.5, y + 0.5) - Vector2(size) / 2.0, n.normalized()])
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var picked: Array = []
	for c: Array in candidates:
		if picked.size() >= max_count:
			break
		var p: Vector2 = c[0]
		if picked.any(func(o: Dictionary) -> bool: return o["pos"].distance_to(p) < spacing):
			continue
		picked.append({"pos": p, "dir": c[1], "len": rng.randf_range(len_min, len_max),
			"phase": rng.randf() * TAU})
	return picked

func start_swing(sword_range: float) -> void:
	_swing_range = sword_range

func hurt() -> void:
	_hurt = 0.18

func die() -> void:
	_dead = 0.001

func revive() -> void:
	_dead = 0.0
	_hurt = 0.0
	_set_param("dissolve", 0.0)

func _process(delta: float) -> void:
	_t += delta
	if _dead > 0.0:
		_dead += delta
		_set_param("dissolve", clampf(_dead / 0.8, 0.0, 1.0))
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
		# Épée corrompue : estoc à la couleur de l'Œil.
		var col: Color = Data.CORRUPT_COLOR if Save.sword_corrupt else SLASH_COLORS[Save.sword_tier]
		_slash.show_arc(base_angle - PI / 3.2, base_angle + (progress - 0.5) * (PI / 1.6),
			_swing_range, col, 1.0 - progress * 0.6)
	else:
		_slash.hide_arc()
	_rig.position = Vector2(0, bob) + lunge
	_rig.rotation = sin(_t * 11.0) * 0.05 if moving else 0.0
	# Emporté par la tornade de cendres : il tournoie sur lui-même.
	if held_by != null and is_instance_valid(held_by) and held_by.sp_attack == "tornado_spin":
		_rig.rotation = _t * 18.0
	_hurt = maxf(0.0, _hurt - delta)
	_set_param("flash", 0.9 if _hurt > 0.0 else 0.0)
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

## Pics violets qui sortent de l'épée et de l'armure corrompues. Dessinés en
## texels, sous le calque concerné : `_rig` les met à l'échelle et les retourne
## avec le héros. Ils palpitent un peu, pour qu'on les voie vivre.
class Spikes extends Node2D:
	const DARK := Color(0.32, 0.08, 0.5)
	const TIP := Color(0.95, 0.78, 1.0)
	var spikes: Array = []
	var _t := 0.0

	func set_spikes(list: Array) -> void:
		spikes = list
		visible = not list.is_empty()
		queue_redraw()

	func _process(delta: float) -> void:
		if spikes.is_empty():
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for sp: Dictionary in spikes:
			var dir: Vector2 = sp["dir"]
			var side := dir.orthogonal() * 1.3
			# Base enfoncée d'un demi-texel sous le sprite.
			var base: Vector2 = sp["pos"] - dir * 0.5
			var length: float = sp["len"] * (1.0 + 0.12 * sin(_t * 3.0 + sp["phase"]))
			var pts := PackedVector2Array([base + side, base + dir * (length + 0.5), base - side])
			draw_polygon(pts, PackedColorArray([DARK, TIP, DARK]))
