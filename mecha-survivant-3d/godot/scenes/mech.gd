extends Node3D
# Le mech du joueur. Deux parties qui tournent indépendamment :
# - les jambes s'orientent dans le sens de la marche ;
# - le torse (et ses deux canons) suit la caméra, donc la visée.
# Pas de physique : déplacement direct, collisions par cercles (main.gd).

const Shapes := preload("res://scenes/shapes.gd")

const SPEED := 9.0
const DASH_SPEED := 28.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 1.1
const FIRE_INTERVAL := 0.1
const BULLET_DAMAGE := 10.0
const RADIUS := 1.1
const MAX_HP := 100.0
const HIT_INVULN := 0.35

var hp := MAX_HP
var immortal := false
var move_dir := Vector3.ZERO  # direction voulue, longueur 0..1
var aim_yaw := 0.0

var legs: Node3D
var torso: Node3D
var leg_pivots: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var cannons: Array[Node3D] = []
var cockpit_mat: StandardMaterial3D
var hull_mat: StandardMaterial3D

var _walk_phase := 0.0
var _fire_cd := 0.0
var _muzzle_i := 0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO
var _invuln := 0.0
var _hurt_flash := 0.0
var _recoil: Array[float] = [0.0, 0.0]


func _ready() -> void:
	_build()


func _build() -> void:
	hull_mat = Shapes.mat(Color(0.42, 0.47, 0.52), 0.6, 0.45)
	var dark := Shapes.mat(Color(0.16, 0.17, 0.2), 0.5, 0.6)
	var accent := Shapes.mat(Color(0.85, 0.55, 0.12), 0.3, 0.5)
	cockpit_mat = Shapes.glow_mat(Color(0.25, 0.9, 1.0), 2.0)

	legs = Shapes.pivot(self, Vector3.ZERO)
	Shapes.box(legs, Vector3(1.5, 0.45, 0.9), Vector3(0, 1.75, 0), dark)  # bassin
	for side in [-1.0, 1.0]:
		var hip := Shapes.pivot(legs, Vector3(0.62 * side, 1.7, 0))
		Shapes.box(hip, Vector3(0.48, 0.95, 0.6), Vector3(0, -0.45, 0), hull_mat)
		Shapes.box(hip, Vector3(0.42, 0.85, 0.5), Vector3(0, -1.15, 0.08), dark)
		Shapes.box(hip, Vector3(0.3, 0.3, 0.3), Vector3(0, -0.85, -0.3), accent)  # genou
		Shapes.box(hip, Vector3(0.62, 0.18, 1.0), Vector3(0, -1.6, -0.12), hull_mat)  # pied
		leg_pivots.append(hip)

	torso = Shapes.pivot(self, Vector3(0, 2.0, 0))
	Shapes.box(torso, Vector3(1.9, 1.05, 1.5), Vector3(0, 0.45, 0), hull_mat)
	Shapes.box(torso, Vector3(1.4, 0.35, 1.2), Vector3(0, 1.1, 0.05), dark)
	Shapes.box(torso, Vector3(1.05, 0.42, 0.2), Vector3(0, 0.6, -0.78), cockpit_mat)  # visière
	Shapes.box(torso, Vector3(1.2, 0.7, 0.5), Vector3(0, 0.55, 0.85), dark)  # réacteur dorsal
	Shapes.box(torso, Vector3(0.25, 0.25, 0.1), Vector3(-0.35, 0.55, 1.12), Shapes.glow_mat(Color(1.0, 0.45, 0.1), 2.5))
	Shapes.box(torso, Vector3(0.25, 0.25, 0.1), Vector3(0.35, 0.55, 1.12), Shapes.glow_mat(Color(1.0, 0.45, 0.1), 2.5))
	Shapes.cylinder(torso, 0.04, 0.9, Vector3(0.6, 1.6, 0.3), dark, 6)  # antenne
	for side in [-1.0, 1.0]:
		var arm := Shapes.pivot(torso, Vector3(1.25 * side, 0.45, 0))
		Shapes.box(arm, Vector3(0.6, 0.7, 0.8), Vector3.ZERO, accent)  # épaule
		var cannon := Shapes.pivot(arm, Vector3(0, -0.15, -0.3))
		Shapes.box(cannon, Vector3(0.45, 0.45, 1.3), Vector3(0, 0, -0.4), dark)
		var barrel := Shapes.cylinder(cannon, 0.12, 0.9, Vector3(0, 0, -1.3), hull_mat, 8)
		barrel.rotation.x = PI / 2
		var muzzle := Shapes.pivot(cannon, Vector3(0, 0, -1.8))
		muzzles.append(muzzle)
		cannons.append(cannon)


func reset() -> void:
	hp = MAX_HP
	position = Vector3.ZERO
	_dash_t = 0.0
	_dash_cd = 0.0
	_invuln = 0.0
	_fire_cd = 0.0


func is_dashing() -> bool:
	return _dash_t > 0.0


func dash_ready() -> float:
	return 1.0 - clampf(_dash_cd / DASH_COOLDOWN, 0.0, 1.0)


func try_dash() -> bool:
	if _dash_cd > 0.0:
		return false
	_dash_dir = move_dir.normalized() if move_dir.length() > 0.1 else Vector3(-sin(aim_yaw), 0, -cos(aim_yaw))
	_dash_t = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_invuln = maxf(_invuln, DASH_TIME + 0.05)
	return true


# Renvoie le déplacement voulu pour cette frame ; main.gd le corrige
# (obstacles, bord de l'arène) avant de l'appliquer.
func step(delta: float) -> Vector3:
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	var motion: Vector3
	if _dash_t > 0.0:
		_dash_t -= delta
		motion = _dash_dir * DASH_SPEED * delta
	else:
		motion = move_dir * SPEED * delta
	_animate(delta, motion.length() / maxf(delta, 0.0001))
	return motion


func _animate(delta: float, speed: float) -> void:
	torso.rotation.y = lerp_angle(torso.rotation.y, aim_yaw, minf(1.0, delta * 18.0))
	if move_dir.length() > 0.1:
		var target := atan2(-move_dir.x, -move_dir.z)
		# Marche arrière : les jambes restent tournées vers l'avant plutôt que
		# de faire volte-face à chaque pas en arrière.
		if absf(angle_difference(target, aim_yaw)) > PI * 0.6:
			target = target + PI
		legs.rotation.y = lerp_angle(legs.rotation.y, target, minf(1.0, delta * 10.0))
	var amount := clampf(speed / SPEED, 0.0, 1.0)
	_walk_phase += delta * (4.0 + 6.0 * amount) * (1.0 if amount > 0.05 else 0.0)
	var swing := sin(_walk_phase) * 0.55 * amount
	leg_pivots[0].rotation.x = swing
	leg_pivots[1].rotation.x = -swing
	var bob := absf(cos(_walk_phase)) * 0.12 * amount
	torso.position.y = 2.0 + bob
	legs.position.y = bob * 0.5
	for i in 2:
		_recoil[i] = move_toward(_recoil[i], 0.0, delta * 3.0)
		cannons[i].position.z = -0.3 + _recoil[i]
	_hurt_flash = maxf(_hurt_flash - delta * 4.0, 0.0)
	hull_mat.emission_enabled = _hurt_flash > 0.0
	hull_mat.emission = Color(1, 0.2, 0.1) * _hurt_flash


# Tire un obus si la cadence le permet, en alternant les canons. Renvoie
# [origine, direction] ou [] si le canon n'est pas prêt.
func try_fire(target: Vector3) -> Array:
	if _fire_cd > 0.0 or is_dashing():
		return []
	_fire_cd = FIRE_INTERVAL
	var muzzle := muzzles[_muzzle_i]
	_recoil[_muzzle_i] = 0.25
	_muzzle_i = 1 - _muzzle_i
	var origin := muzzle.global_position
	var dir := (target - origin).normalized()
	return [origin, dir]


func take_damage(amount: float) -> bool:
	if immortal or _invuln > 0.0 or hp <= 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	_invuln = HIT_INVULN
	_hurt_flash = 1.0
	return true
