class_name CameraRig
extends Camera3D
## Caméra à l'épaule droite du mech, reprise du prototype, plus ce que le
## village impose :
## - **recul anti-mur** : si un mur se glisse entre le mech et la caméra, elle
##   s'avance jusqu'à lui (instantanément), puis reprend sa distance en
##   douceur une fois la vue dégagée ;
## - la **visée** : un rayon part du centre de l'écran et s'arrête sur le
##   premier ennemi, mur ou bout de sol rencontré ; les canons convergent vers
##   ce point.

const DIST := 7.5
const HEIGHT := 3.4
const SHOULDER := 1.3
const MIN_DIST := 1.6
const PITCH_MIN := -0.95
const PITCH_MAX := 0.3
const AIM_RANGE := 140.0

var yaw := 0.0
var pitch := -0.2
var target: Node3D
var aim_point := Vector3.ZERO
var aim_enemy: Enemy = null
var shake := 0.0
## Distance réellement tenue (raccourcie par les murs).
var current_dist := DIST

func _ready() -> void:
	fov = 72.0
	near = 0.1
	far = 220.0

func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))

func look_dir() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))

func add_look(dx: float, dy: float) -> void:
	yaw -= dx
	pitch = clampf(pitch - dy, PITCH_MIN, PITCH_MAX)

func follow(delta: float) -> void:
	if target == null:
		return
	shake = maxf(shake - delta * 3.0, 0.0)
	var d := look_dir()
	var pivot := target.position + Vector3(0, HEIGHT, 0)
	var offset := -d * DIST + right_flat() * SHOULDER
	var wanted := DIST
	var v := Village.current
	if v != null:
		# Le rayon part du haut du mech, juste au-dessus des canons : un mur
		# bas (tombe, pan écroulé) ne fait pas avancer la caméra.
		var hit: Variant = v.segment_hit(pivot, pivot + offset, 0.25)
		if hit != null:
			wanted = maxf(MIN_DIST, pivot.distance_to(hit) - 0.5)
	if wanted < current_dist:
		current_dist = wanted
	else:
		current_dist = move_toward(current_dist, wanted, delta * 6.0)
	var pos := pivot + offset * (current_dist / DIST)
	pos.y = maxf(pos.y, 0.6)
	if shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.25
	global_position = pos
	look_at(pos + d, Vector3.UP)

## Ce que vise le réticule : l'ennemi le plus proche sur le rayon, sinon le
## mur ou le sol, sinon un point lointain.
func update_aim(enemies: Array) -> void:
	var origin := global_position
	var dir := -global_transform.basis.z
	var skip := current_dist + 1.5
	var best := AIM_RANGE
	aim_enemy = null
	for node in enemies:
		var e := node as Enemy
		if e == null or not e.alive:
			continue
		var t := _ray_sphere(origin, dir, e.aim_point(), maxf(e.radius * 1.2, e.height * 0.45))
		if t > skip and t < best:
			best = t
			aim_enemy = e
	var v := Village.current
	if v != null:
		var far_end := origin + dir * best
		var hit: Variant = v.segment_hit(origin + dir * skip, far_end, 0.4)
		if hit != null:
			best = origin.distance_to(hit)
			aim_enemy = null
	aim_point = origin + dir * best

static func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc := o - c
	var b := oc.dot(d)
	var disc := b * b - (oc.length_squared() - r * r)
	if disc < 0.0:
		return -1.0
	return -b - sqrt(disc)
