class_name Bullet
extends Node3D
## Obus du mech. Segment testé contre la capsule de chaque ennemi, puis contre
## les murs et le sol du village.
##
## Écart assumé avec la v2 : la v2 tirait à 420 px/s (26 m/s). Vu de l'épaule,
## les cibles sont plus loin qu'à l'écran d'une vue de dessus et un obus aussi
## lent rate tout ce qui bouge ; il vole ici à `SPEED`, sur une portée
## comparable à ce que la v2 couvrait en deux secondes.

const SPEED := 60.0
const LIFETIME := 1.1
const HIT_COLOR := Color(1.0, 0.75, 0.3)

var direction := Vector3.FORWARD
var damage := 12.0
var _life := LIFETIME
static var _mesh: BoxMesh
static var _mat: StandardMaterial3D

func setup(from: Vector3, dir: Vector3, dmg: float) -> void:
	position = from
	direction = dir
	damage = dmg

func _ready() -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.14, 0.14, 1.8)
		_mat = Shapes.glow_mat(Color(1.0, 0.8, 0.3), 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	look_at(position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)

func _process(delta: float) -> void:
	if not GameState.running:
		return
	var from := position
	var to := from + direction * SPEED * delta
	_life -= delta
	var best: Enemy = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.is_damage_immune():
			continue
		if e.segment_hits(from, to, 0.07):
			var d := from.distance_squared_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	if best != null:
		var at := Geometry3D.get_closest_point_to_segment(best.aim_point(), from, to)
		best.take_damage(damage, at)
		queue_free()
		return
	var wall: Variant = null
	if Village.current != null:
		wall = Village.current.segment_hit(from, to, 0.4)
	elif to.y <= 0.0:
		wall = to
	if wall != null:
		Shapes.burst(get_parent(), wall, HIT_COLOR, 4, 4.0, 0.08, true)
		queue_free()
		return
	if _life <= 0.0:
		queue_free()
		return
	position = to
