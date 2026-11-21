class_name Shapes
extends RefCounted
## Petites fabriques de primitives : tout le jeu est construit en code, sans
## modèle 3D ni scène éditée à la main.

static func mat(color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

## Matériau lumineux, insensible à l'éclairage : yeux, flammes, réacteurs.
## `energy` > 1 le fait déborder dans le glow de l'environnement.
static func glow_mat(color: Color, energy := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	return m

## Matériau translucide (ombres, bouclier) : alpha réglable après coup.
static func ghost_mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, pos, material)

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material,
		sides := 12, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _instance(parent, mesh, pos, material)

static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material, segments := 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments >> 1)
	return _instance(parent, mesh, pos, material)

static func _instance(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

static func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

## Gerbe d'éclats à usage unique, libérée d'elle-même.
static func burst(parent: Node, at: Vector3, color: Color, amount := 18, speed := 7.0,
		size := 0.18, glow := false) -> void:
	if GameState.smoke_test:
		return
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	p.mesh = mesh
	p.material_override = glow_mat(color, 2.5) if glow else mat(color, 0.2, 0.6)
	p.amount = amount
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)

## Flammes continues accrochées à un nœud (squelette de feu, flameling,
## mech embrasé). `emitting` se coupe et se rallume à volonté.
static func flames(parent: Node3D, pos: Vector3, radius := 0.25, amount := 12,
		color := Color(1.0, 0.45, 0.12)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.14
	p.mesh = mesh
	p.material_override = glow_mat(color, 3.0)
	p.amount = amount
	p.lifetime = 0.55
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 1.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos
	parent.add_child(p)
	return p
