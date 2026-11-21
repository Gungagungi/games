class_name VillageBuilder
extends RefCounted
## Monte en 3D la grille de `Village` : sol, murs, obstacles, décor, lumières.
## Tout est géométrie de code, sans modèle ni texture.
##
## Ce qui compte pour tenir dans un navigateur :
## - les murs sont **fusionnés** en un maillage par tronçon de carte
##   (`CHUNK` cases de côté), sans les faces cachées entre deux cases de mur ;
## - le sol est un plan par tronçon, peint par un seul shader qui lit la
##   nature des cases dans une petite texture ;
## - obstacles et décor passent par des `MultiMesh` : une pièce (tronc,
##   tonneau, tombe…) = un appel de dessin, quel que soit leur nombre ;
## - le découpage en tronçons sert aussi l'éclairage : en rendu Compatibility,
##   un objet ne reçoit que quelques lumières — un seul maillage pour toute la
##   carte n'en verrait que huit.

const CHUNK := 16
const GroundShader := preload("res://world/ground.gdshader")
const WallShader := preload("res://world/wall.gdshader")

const STONE := Color(0.36, 0.34, 0.33)
const RAMPART := Color(0.27, 0.26, 0.27)

static func build(v: Village) -> Node3D:
	var root := Node3D.new()
	root.name = "VillageVisual"
	_build_ground(v, root)
	_build_walls(v, root)
	var batch := Batch.new()
	_build_props(v, batch)
	_build_lights(v, root, batch)
	batch.flush(root)
	return root

# --- sol -------------------------------------------------------------------

static func _build_ground(v: Village, root: Node3D) -> void:
	var img := Image.create(Village.COLS, Village.ROWS, false, Image.FORMAT_RGBA8)
	for y in Village.ROWS:
		for x in Village.COLS:
			var c := Vector2i(x, y)
			var k := v.kind_at(c)
			img.set_pixel(x, y, Color8(k, (v.variant_at(c) % 5) * 60, 0, 255))
	var mat := ShaderMaterial.new()
	mat.shader = GroundShader
	mat.set_shader_parameter("cell_map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("cell", Village.CELL)
	mat.set_shader_parameter("cols", Village.COLS)
	mat.set_shader_parameter("rows", Village.ROWS)
	var size := CHUNK * Village.CELL
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	for cy in ceili(float(Village.ROWS) / CHUNK):
		for cx in ceili(float(Village.COLS) / CHUNK):
			var mi := MeshInstance3D.new()
			mi.mesh = plane
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3((cx + 0.5) * size, 0.0, (cy + 0.5) * size)
			root.add_child(mi)
	# Au-delà du rempart : une lande sombre, pour que l'horizon ne soit pas vide.
	var outer := MeshInstance3D.new()
	var big := PlaneMesh.new()
	big.size = Vector2(700, 700)
	outer.mesh = big
	outer.material_override = Shapes.mat(Color(0.05, 0.06, 0.045), 0.0, 1.0)
	outer.position = Vector3(v.world_size().x * 0.5, -0.05, v.world_size().y * 0.5)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outer)

# --- murs ------------------------------------------------------------------

## Une case « mur » au sens du maillage : les vrais murs et les pans écroulés.
static func _wall_like(v: Village, c: Vector2i) -> bool:
	var k := v.kind_at(c)
	return k == Village.WALL or (k == Village.BLOCK and v.prop_at(c) == Village.Prop.STUB)

static func _build_walls(v: Village, root: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WallShader
	for cy in ceili(float(Village.ROWS) / CHUNK):
		for cx in ceili(float(Village.COLS) / CHUNK):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var any := false
			for y in range(cy * CHUNK, mini((cy + 1) * CHUNK, Village.ROWS)):
				for x in range(cx * CHUNK, mini((cx + 1) * CHUNK, Village.COLS)):
					var c := Vector2i(x, y)
					if _wall_like(v, c):
						_wall_cell(v, st, c)
						any = true
			if not any:
				continue
			st.generate_normals()
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat
			root.add_child(mi)

## Un bloc de pierre par case : le dessus, et chaque face latérale là où la
## voisine est plus basse (de sa hauteur à la nôtre). Les faces entre deux
## murs de même hauteur ne sont jamais émises.
static func _wall_cell(v: Village, st: SurfaceTool, c: Vector2i) -> void:
	var h := v.height_at_cell(c)
	var x0 := c.x * Village.CELL
	var z0 := c.y * Village.CELL
	var x1 := x0 + Village.CELL
	var z1 := z0 + Village.CELL
	var border := c.x == 0 or c.y == 0 or c.x == Village.COLS - 1 or c.y == Village.ROWS - 1
	var tint := (RAMPART if border else STONE) * (0.85 + float(v.variant_at(c) % 13) * 0.025)
	tint.a = 1.0
	st.set_color(tint)
	# Dessus.
	_quad(st, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1))
	var sides := [
		[Vector2i(0, -1), Vector3(x1, 0, z0), Vector3(x0, 0, z0)],
		[Vector2i(1, 0), Vector3(x1, 0, z1), Vector3(x1, 0, z0)],
		[Vector2i(0, 1), Vector3(x0, 0, z1), Vector3(x1, 0, z1)],
		[Vector2i(-1, 0), Vector3(x0, 0, z0), Vector3(x0, 0, z1)],
	]
	for s in sides:
		var n: Vector2i = c + (s[0] as Vector2i)
		var nh := 0.0
		if not v.inside(n):
			continue
		if _wall_like(v, n):
			nh = v.height_at_cell(n)
		if nh >= h:
			continue
		var a: Vector3 = s[1]
		var b: Vector3 = s[2]
		_quad(st, Vector3(a.x, h, a.z), Vector3(b.x, h, b.z), Vector3(b.x, nh, b.z), Vector3(a.x, nh, a.z))

## Quadrilatère a-b-c-d, vu de face quand les sommets tournent dans le sens
## horaire (convention de Godot).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

# --- obstacles et décor ------------------------------------------------------

static func _build_props(v: Village, b: Batch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in Village.ROWS:
		for x in Village.COLS:
			var c := Vector2i(x, y)
			var p2 := v.cell_center(c)
			var at := Vector3(p2.x, 0.0, p2.y)
			match v.prop_at(c):
				Village.Prop.TREE:
					_tree(b, at, rng)
				Village.Prop.ROCK:
					_rocks(b, at, rng)
				Village.Prop.BARREL:
					_barrels(b, at, rng)
				Village.Prop.GRAVE:
					_grave(b, at, rng)
				Village.Prop.STUB:
					_rubble(b, at, rng, 4)
				Village.Prop.FURNITURE:
					_furniture(b, at, rng)
			# Gravats au pied des murs de maison, côté intérieur ou rue.
			if v.kind_at(c) == Village.FLOOR and rng.randf() < 0.06:
				_rubble(b, at, rng, 2)

static func _tree(b: Batch, at: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.85, 1.2)
	var yaw := rng.randf() * TAU
	var lean := Basis(Vector3(1, 0, 0), rng.randf_range(-0.08, 0.08)).rotated(Vector3.UP, yaw)
	b.add("trunk", lean.scaled(Vector3.ONE * s), at + Vector3(0, 2.1 * s, 0))
	for i in rng.randi_range(3, 5):
		var h := rng.randf_range(2.2, 4.0) * s
		var ang := yaw + i * TAU / 4.0 + rng.randf_range(-0.4, 0.4)
		var tilt := rng.randf_range(0.6, 1.1)
		var basis := Basis(Vector3(0, 0, 1), tilt).rotated(Vector3.UP, ang)
		var scale := rng.randf_range(0.7, 1.1) * s
		var dir := basis * Vector3.UP
		b.add("branch", basis.scaled(Vector3.ONE * scale), at + Vector3(0, h, 0) + dir * 0.8 * scale)

static func _rocks(b: Batch, at: Vector3, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(1, 3):
		var s := Vector3(rng.randf_range(0.7, 1.1), rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.1))
		if i > 0:
			s *= 0.5
		var off := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)) if i > 0 else Vector3.ZERO
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(s)
		b.add("rock", basis, at + off + Vector3(0, s.y * 0.45, 0))

static func _barrels(b: Batch, at: Vector3, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(1, 3)
	for i in n:
		var off := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45)) if n > 1 else Vector3.ZERO
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if i == 2:
			# Le troisième est couché.
			basis = Basis(Vector3(1, 0, 0), PI / 2).rotated(Vector3.UP, rng.randf() * TAU)
			b.add("barrel", basis, at + off + Vector3(0, 0.42, 0))
			continue
		b.add("barrel", basis, at + off + Vector3(0, 0.58, 0))
		b.add("band", basis, at + off + Vector3(0, 0.25, 0))
		b.add("band", basis, at + off + Vector3(0, 0.9, 0))

static func _grave(b: Batch, at: Vector3, rng: RandomNumberGenerator) -> void:
	var tilt := Basis(Vector3(1, 0, 0), rng.randf_range(-0.15, 0.12)) \
		.rotated(Vector3(0, 0, 1), rng.randf_range(-0.12, 0.12))
	var base := at + Vector3(0, 0, -0.45)
	if rng.randf() < 0.6:
		b.add("stone_slab", tilt, base + Vector3(0, 0.5, 0))
		b.add("stone_round", tilt * Basis(Vector3(1, 0, 0), PI / 2), base + tilt * Vector3(0, 1.0, 0))
	else:
		b.add("cross_post", tilt, base + Vector3(0, 0.6, 0))
		b.add("cross_bar", tilt, base + tilt * Vector3(0, 0.85, 0))
	b.add("mound", Basis.IDENTITY, at + Vector3(0, 0.08, 0.3))

static func _rubble(b: Batch, at: Vector3, rng: RandomNumberGenerator, count: int) -> void:
	for i in count:
		var s := rng.randf_range(0.25, 0.6)
		var off := Vector3(rng.randf_range(-0.9, 0.9), s * 0.3, rng.randf_range(-0.9, 0.9))
		var basis := Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)).scaled(Vector3(s * 1.3, s * 0.7, s))
		b.add("rubble", basis, at + off)

## Mobilier renversé (sans collision, comme dans la v2) : table, chaise
## couchée ou caisse éventrée.
static func _furniture(b: Batch, at: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := Basis(Vector3.UP, rng.randf() * TAU)
	match rng.randi() % 3:
		0:
			b.add("table_top", yaw, at + Vector3(0, 0.75, 0))
			for sx in [-0.6, 0.6]:
				for sz in [-0.32, 0.32]:
					b.add("leg", yaw, at + yaw * Vector3(sx, 0.37, sz))
		1:
			var fallen := yaw * Basis(Vector3(1, 0, 0), PI / 2)
			b.add("chair_seat", fallen, at + Vector3(0, 0.25, 0))
			b.add("chair_back", fallen, at + fallen * Vector3(0, 0.0, -0.3) + Vector3(0, 0.25, 0))
		_:
			b.add("crate", yaw * Basis(Vector3(0, 0, 1), 0.2), at + Vector3(0, 0.4, 0))

# --- lumières ----------------------------------------------------------------

static func _build_lights(v: Village, root: Node3D, b: Batch) -> void:
	for i in v.light_spots.size():
		var p: Vector3 = v.light_spots[i]
		var brazier := i < 4
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.56, 0.24)
		light.light_energy = 2.6 if brazier else 1.8
		light.omni_range = 15.0 if brazier else 12.0
		light.omni_attenuation = 1.2
		if brazier:
			b.add("brazier_bowl", Basis.IDENTITY, p + Vector3(0, 0.55, 0))
			b.add("ember", Basis.IDENTITY, p + Vector3(0, 1.15, 0))
			light.position = p + Vector3(0, 2.0, 0)
			_flames(root, p + Vector3(0, 1.2, 0))
		else:
			b.add("pole", Basis.IDENTITY, p + Vector3(0, 1.6, 0))
			b.add("lamp_arm", Basis.IDENTITY, p + Vector3(0.35, 3.1, 0))
			b.add("lamp", Basis.IDENTITY, p + Vector3(0.7, 2.85, 0))
			light.position = p + Vector3(0.7, 2.6, 0)
		root.add_child(light)

static func _flames(root: Node3D, at: Vector3) -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.18
	p.mesh = mesh
	p.material_override = Shapes.glow_mat(Color(1.0, 0.45, 0.12), 3.0)
	p.amount = 14
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, 1.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = at
	root.add_child(p)


## Regroupe les pièces de décor par maillage, puis en fait un MultiMesh chacun.
class Batch:
	var _xforms: Dictionary = {}

	func add(key: String, basis: Basis, origin: Vector3) -> void:
		if not _xforms.has(key):
			_xforms[key] = []
		(_xforms[key] as Array).append(Transform3D(basis, origin))

	func flush(root: Node3D) -> void:
		for key: String in _xforms:
			var list: Array = _xforms[key]
			var def := _piece(key)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = def[0]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = def[1]
			if def.size() > 2 and not def[2]:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)

	## [maillage, matériau, ombre portée ?] de chaque pièce.
	static func _piece(key: String) -> Array:
		var bark := Shapes.mat(Color(0.16, 0.12, 0.1), 0.0, 1.0)
		var stone := Shapes.mat(Color(0.34, 0.34, 0.35), 0.0, 0.9)
		var wood := Shapes.mat(Color(0.32, 0.2, 0.11), 0.0, 0.85)
		var iron := Shapes.mat(Color(0.14, 0.14, 0.16), 0.7, 0.5)
		match key:
			"trunk":
				return [_cyl(0.16, 0.42, 4.2, 7), bark]
			"branch":
				return [_cyl(0.03, 0.13, 1.8, 5), bark]
			"rock":
				var s := SphereMesh.new()
				s.radius = 0.9
				s.height = 1.6
				s.radial_segments = 7
				s.rings = 4
				return [s, Shapes.mat(Color(0.3, 0.3, 0.31), 0.0, 0.95)]
			"barrel":
				return [_cyl(0.4, 0.4, 1.15, 10), wood]
			"band":
				return [_cyl(0.425, 0.425, 0.08, 10), iron]
			"stone_slab":
				return [_box(Vector3(0.8, 1.0, 0.22)), stone]
			"stone_round":
				return [_cyl(0.4, 0.4, 0.22, 10), stone]
			"cross_post":
				return [_box(Vector3(0.16, 1.2, 0.16)), stone]
			"cross_bar":
				return [_box(Vector3(0.7, 0.16, 0.16)), stone]
			"mound":
				return [_box(Vector3(0.85, 0.18, 1.3)), Shapes.mat(Color(0.16, 0.12, 0.08), 0.0, 1.0), false]
			"rubble":
				return [_box(Vector3.ONE), Shapes.mat(Color(0.3, 0.29, 0.28), 0.0, 0.95)]
			"table_top":
				return [_box(Vector3(1.4, 0.08, 0.8)), wood]
			"leg":
				return [_box(Vector3(0.08, 0.74, 0.08)), wood]
			"chair_seat":
				return [_box(Vector3(0.5, 0.06, 0.5)), wood]
			"chair_back":
				return [_box(Vector3(0.5, 0.6, 0.06)), wood]
			"crate":
				return [_box(Vector3(0.8, 0.8, 0.8)), Shapes.mat(Color(0.38, 0.26, 0.14), 0.0, 0.85)]
			"brazier_bowl":
				return [_cyl(0.55, 0.3, 1.1, 10), iron]
			"ember":
				return [_box(Vector3(0.75, 0.2, 0.75)), Shapes.glow_mat(Color(1.0, 0.42, 0.1), 3.0), false]
			"pole":
				return [_cyl(0.07, 0.09, 3.2, 6), iron]
			"lamp_arm":
				return [_box(Vector3(0.8, 0.06, 0.06)), iron]
			"lamp":
				return [_box(Vector3(0.28, 0.4, 0.28)), Shapes.glow_mat(Color(1.0, 0.7, 0.35), 2.6), false]
		return [_box(Vector3.ONE), stone]

	static func _box(size: Vector3) -> BoxMesh:
		var m := BoxMesh.new()
		m.size = size
		return m

	static func _cyl(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = sides
		m.rings = 1
		return m
