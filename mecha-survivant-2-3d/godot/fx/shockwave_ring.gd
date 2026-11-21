class_name ShockwaveRing
extends Node3D
## Anneau de l'onde de choc, au ras du sol. Purement visuel : les dégâts sont
## appliqués d'un coup au déclenchement (v2 : `shockwave.gd`, 0,35 s).

const DURATION := 0.35

var max_radius := 8.75
var _t := 0.0
var _ring: MeshInstance3D
var _inner: MeshInstance3D
var _mat: StandardMaterial3D
var _mat_inner: StandardMaterial3D

func _ready() -> void:
	_mat = Shapes.ghost_mat(Color(0.45, 0.85, 1.0, 1.0), true)
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_inner = Shapes.ghost_mat(Color(1.0, 1.0, 1.0, 0.5), true)
	_mat_inner.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring = _torus(0.85, _mat)
	_inner = _torus(0.75, _mat_inner)
	_inner.position.y = 0.3

func _torus(inner_ratio: float, m: Material) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner_ratio
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.5
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	var p := _t / DURATION
	var r := maxf(0.1, max_radius * ease(p, 0.4))
	_ring.scale = Vector3(r, 1.0 + 2.0 * (1.0 - p), r)
	_inner.scale = Vector3(r * 0.8, 1.0, r * 0.8)
	_mat.albedo_color.a = 1.0 - p
	_mat_inner.albedo_color.a = 0.5 * (1.0 - p)
