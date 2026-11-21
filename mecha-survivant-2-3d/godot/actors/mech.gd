class_name Mech
extends Node3D
## Le mech du joueur. Stats et règles de `mecha-survivant-2/godot/scenes/
## player/player.gd` (dash à endurance, bouclier régénérant, embrasement,
## salve en éventail, onde de choc), converties en mètres.
##
## Deux parties qui tournent indépendamment :
## - les jambes s'orientent dans le sens de la marche ;
## - le torse (et ses deux canons) suit la caméra, donc la visée.
## Pas de physique : `step()` renvoie le déplacement voulu, `main.gd` le fait
## glisser le long des murs (`Village.move_circle`).

const PX := Units.PX
const BASE_SPEED := 156.0 * PX
const DASH_SPEED := 540.0 * PX
const DASH_DURATION := 8.0 / 60.0
const DASH_COOLDOWN := 45.0 / 60.0
const DASH_INVULN := 10.0 / 60.0
const DASH_COST := 25.0
const STAMINA_REGEN := 18.0
const SHIELD_REGEN := 15.0
const SHIELD_REGEN_DELAY := 2.0
const AOE_COOLDOWN := 5.0
const AOE_RADIUS := 140.0 * PX
const AOE_DAMAGE := 60.0
const HIT_INVULN := 0.5
const SALVO_SPREAD := deg_to_rad(9.0)
const RADIUS := 1.0
## Centre du corps, visé par les projectiles ennemis.
const CENTER_HEIGHT := 1.9
const HEIGHT := 3.4

var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var shield_max := 0.0
var shield := 0.0
var speed := BASE_SPEED
var bullet_damage := 12.0
var fire_interval := 24.0 / 60.0
var multi_shot := 1
var aoe_unlocked := false

var invuln := 0.0
var burn_time := 0.0
var burn_dps := 0.0
var dash_cd := 0.0
var aoe_cd := 0.0
var fire_cd := 0.0
var since_damage := 0.0
var alive := true
var immortal := false

var move_dir := Vector3.ZERO  ## direction voulue, longueur 0..1
var aim_yaw := 0.0

var _dash_time := 0.0
var _dash_dir := Vector3.ZERO

var legs: Node3D
var torso: Node3D
var _leg_pivots: Array[Node3D] = []
var _muzzles: Array[Node3D] = []
var _cannons: Array[Node3D] = []
var _flashes: Array[MeshInstance3D] = []
var _hull_mat: StandardMaterial3D
var _shield_mat: StandardMaterial3D
var _shield_bubble: MeshInstance3D
var _thrusters: CPUParticles3D
var _burn_fx: CPUParticles3D
var _walk_phase := 0.0
var _muzzle_i := 0
var _hurt_flash := 0.0
var _shield_flash := 0.0
var _recoil: Array[float] = [0.0, 0.0]
var _flash_t: Array[float] = [0.0, 0.0]

func _ready() -> void:
	add_to_group("player")
	_build()

func _build() -> void:
	_hull_mat = Shapes.mat(Color(0.42, 0.47, 0.52), 0.6, 0.45)
	var dark := Shapes.mat(Color(0.16, 0.17, 0.2), 0.5, 0.6)
	var accent := Shapes.mat(Color(0.85, 0.55, 0.12), 0.3, 0.5)
	var cockpit := Shapes.glow_mat(Color(0.25, 0.9, 1.0), 2.0)
	var vent := Shapes.glow_mat(Color(1.0, 0.45, 0.1), 1.6)

	legs = Shapes.pivot(self, Vector3.ZERO)
	Shapes.box(legs, Vector3(1.5, 0.45, 0.9), Vector3(0, 1.75, 0), dark)
	for side in [-1.0, 1.0]:
		var hip := Shapes.pivot(legs, Vector3(0.62 * side, 1.7, 0))
		Shapes.box(hip, Vector3(0.48, 0.95, 0.6), Vector3(0, -0.45, 0), _hull_mat)
		Shapes.box(hip, Vector3(0.42, 0.85, 0.5), Vector3(0, -1.15, 0.08), dark)
		Shapes.box(hip, Vector3(0.3, 0.3, 0.3), Vector3(0, -0.85, -0.3), accent)
		Shapes.box(hip, Vector3(0.62, 0.18, 1.0), Vector3(0, -1.6, -0.12), _hull_mat)
		Shapes.box(hip, Vector3(0.5, 0.12, 0.3), Vector3(0, -1.62, 0.42), dark)  # éperon arrière
		_leg_pivots.append(hip)

	torso = Shapes.pivot(self, Vector3(0, 2.0, 0))
	Shapes.box(torso, Vector3(1.9, 1.05, 1.5), Vector3(0, 0.45, 0), _hull_mat)
	Shapes.box(torso, Vector3(1.4, 0.35, 1.2), Vector3(0, 1.1, 0.05), dark)
	Shapes.box(torso, Vector3(1.05, 0.42, 0.2), Vector3(0, 0.6, -0.78), cockpit)
	Shapes.box(torso, Vector3(1.6, 0.12, 0.3), Vector3(0, 0.95, -0.7), accent)  # bandeau
	Shapes.box(torso, Vector3(1.2, 0.7, 0.5), Vector3(0, 0.55, 0.85), dark)
	# Fentes d'évacuation horizontales : deux carrés lumineux sur le dos se
	# lisaient comme des yeux tournés vers la caméra.
	for k in 3:
		Shapes.box(torso, Vector3(0.8, 0.06, 0.08), Vector3(0, 0.38 + k * 0.15, 1.11), vent)
	Shapes.cylinder(torso, 0.04, 0.9, Vector3(0.6, 1.6, 0.3), dark, 6)
	Shapes.sphere(torso, 0.07, Vector3(0.6, 2.07, 0.3), Shapes.glow_mat(Color(1, 0.2, 0.15), 3.0), 6)
	for side in [-1.0, 1.0]:
		var arm := Shapes.pivot(torso, Vector3(1.25 * side, 0.45, 0))
		Shapes.box(arm, Vector3(0.6, 0.7, 0.8), Vector3.ZERO, accent)
		var cannon := Shapes.pivot(arm, Vector3(0, -0.15, -0.3))
		Shapes.box(cannon, Vector3(0.45, 0.45, 1.3), Vector3(0, 0, -0.4), dark)
		var barrel := Shapes.cylinder(cannon, 0.12, 0.9, Vector3(0, 0, -1.3), _hull_mat, 8)
		barrel.rotation.x = PI / 2
		var muzzle := Shapes.pivot(cannon, Vector3(0, 0, -1.8))
		var flash := Shapes.sphere(muzzle, 0.28, Vector3.ZERO, Shapes.glow_mat(Color(1.0, 0.75, 0.3), 3.5), 6)
		flash.visible = false
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flashes.append(flash)
		_muzzles.append(muzzle)
		_cannons.append(cannon)

	# Phare : la nuit, il éclaire la rue devant le mech.
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 0.7, -0.9)
	lamp.light_color = Color(0.75, 0.9, 1.0)
	lamp.light_energy = 2.2
	lamp.spot_range = 26.0
	lamp.spot_angle = 28.0
	lamp.rotation.x = deg_to_rad(-12.0)
	torso.add_child(lamp)

	_thrusters = Shapes.flames(torso, Vector3(0, 0.55, 1.15), 0.2, 16, Color(0.4, 0.8, 1.0))
	_thrusters.emitting = false
	_burn_fx = Shapes.flames(self, Vector3(0, 2.2, 0), 0.8, 22)
	_burn_fx.emitting = false

	_shield_mat = Shapes.ghost_mat(Color(0.35, 0.7, 1.0, 0.0), true)
	_shield_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shield_bubble = Shapes.sphere(self, 2.2, Vector3(0, 1.8, 0), _shield_mat, 18)
	_shield_bubble.scale = Vector3(1.0, 1.05, 1.0)
	_shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_bubble.visible = false

func reset_stats() -> void:
	max_hp = 100.0
	hp = max_hp
	max_stamina = 100.0
	stamina = max_stamina
	shield_max = 0.0
	shield = 0.0
	speed = BASE_SPEED
	bullet_damage = 12.0
	fire_interval = 24.0 / 60.0
	multi_shot = 1
	aoe_unlocked = false
	invuln = 0.0
	burn_time = 0.0
	burn_dps = 0.0
	_dash_time = 0.0
	dash_cd = 0.0
	aoe_cd = 0.0
	fire_cd = 0.0
	alive = true
	visible = true
	EventBus.player_stats_changed.emit()

func is_dashing() -> bool:
	return _dash_time > 0.0

func can_dash() -> bool:
	return dash_cd <= 0.0 and stamina >= DASH_COST

func center() -> Vector3:
	return position + Vector3(0, CENTER_HEIGHT, 0)

## Dash dans la direction de marche ; à l'arrêt, droit devant (la v2 au doigt
## gardait aussi le dernier cap : au clavier comme au doigt, en 3D, « devant »
## est toujours lisible).
func try_dash() -> bool:
	if not alive or not can_dash():
		return false
	_dash_dir = move_dir.normalized() if move_dir.length() > 0.1 else Vector3(-sin(aim_yaw), 0, -cos(aim_yaw))
	_dash_time = DASH_DURATION
	dash_cd = DASH_COOLDOWN
	invuln = maxf(invuln, DASH_INVULN)
	stamina -= DASH_COST
	AudioManager.sfx("dash", -4.0)
	return true

## Onde de choc prête ? La consomme et renvoie vrai ; les dégâts sont
## appliqués par `main.gd`, qui connaît les ennemis.
func try_shockwave() -> bool:
	if not alive or not aoe_unlocked or aoe_cd > 0.0:
		return false
	aoe_cd = AOE_COOLDOWN
	AudioManager.sfx("shockwave")
	EventBus.screen_shake_requested.emit(1.2)
	return true

## Avance les minuteries et renvoie le déplacement voulu pour cette frame.
func step(delta: float) -> Vector3:
	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	aoe_cd = maxf(0.0, aoe_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	since_damage += delta
	if burn_time > 0.0:
		burn_time = maxf(0.0, burn_time - delta)
		_lose_hp(burn_dps * delta)
	if _dash_time <= 0.0:
		stamina = minf(max_stamina, stamina + STAMINA_REGEN * delta)
	if shield_max > 0.0 and since_damage >= SHIELD_REGEN_DELAY:
		shield = minf(shield_max, shield + SHIELD_REGEN * delta)
	var motion: Vector3
	if _dash_time > 0.0:
		_dash_time -= delta
		motion = _dash_dir * DASH_SPEED * delta
	else:
		motion = move_dir * speed * delta
	_animate(delta, motion.length() / maxf(delta, 0.0001))
	return motion

func _animate(delta: float, spd: float) -> void:
	torso.rotation.y = lerp_angle(torso.rotation.y, aim_yaw, minf(1.0, delta * 18.0))
	if move_dir.length() > 0.1:
		var target := atan2(-move_dir.x, -move_dir.z)
		# Marche arrière : les jambes restent tournées vers l'avant plutôt que
		# de faire volte-face à chaque pas en arrière.
		if absf(angle_difference(target, aim_yaw)) > PI * 0.6:
			target = target + PI
		legs.rotation.y = lerp_angle(legs.rotation.y, target, minf(1.0, delta * 10.0))
	var amount := clampf(spd / BASE_SPEED, 0.0, 1.0)
	_walk_phase += delta * (4.0 + 6.0 * amount) * (1.0 if amount > 0.05 else 0.0)
	var swing := sin(_walk_phase) * 0.55 * amount
	_leg_pivots[0].rotation.x = swing
	_leg_pivots[1].rotation.x = -swing
	var bob := absf(cos(_walk_phase)) * 0.12 * amount
	torso.position.y = 2.0 + bob
	legs.position.y = bob * 0.5
	for i in 2:
		_recoil[i] = move_toward(_recoil[i], 0.0, delta * 3.0)
		_cannons[i].position.z = -0.3 + _recoil[i]
		_flash_t[i] = maxf(0.0, _flash_t[i] - delta)
		_flashes[i].visible = _flash_t[i] > 0.0
	_thrusters.emitting = is_dashing()
	_burn_fx.emitting = burn_time > 0.0
	_hurt_flash = maxf(_hurt_flash - delta * 4.0, 0.0)
	_hull_mat.emission_enabled = _hurt_flash > 0.0
	_hull_mat.emission = Color(1, 0.2, 0.1) * _hurt_flash
	# Bulle de bouclier : à peine visible au repos, vive sous les coups.
	_shield_flash = maxf(_shield_flash - delta * 3.0, 0.0)
	var level := shield / maxf(1.0, shield_max)
	_shield_bubble.visible = shield > 0.5
	_shield_mat.albedo_color.a = 0.02 + 0.04 * level + 0.35 * _shield_flash
	_shield_bubble.rotation.y += delta * 0.6

## Une ou plusieurs salves si la cadence le permet. Chaque salve compte
## `multi_shot` projectiles en éventail (9° entre deux), et part du canon
## suivant. Renvoie la liste des [origine, direction] à créer.
func fire(target: Vector3, delta: float) -> Array:
	if not alive or fire_cd > 0.0 or is_dashing():
		return []
	# `fire_interval` est multiplicatif et sans plafond (v1, v2) : sous une
	# frame, on tire plusieurs salves dans la même frame.
	var salvos := 1
	if fire_interval < delta:
		salvos = mini(20, int(delta / maxf(fire_interval, 0.001)))
	fire_cd = maxf(fire_interval, 0.0) * salvos
	var shots: Array = []
	for s in salvos:
		var muzzle := _muzzles[_muzzle_i]
		_recoil[_muzzle_i] = 0.25
		_flash_t[_muzzle_i] = 0.05
		_muzzle_i = 1 - _muzzle_i
		var origin := muzzle.global_position
		var dir := (target - origin).normalized()
		for i in multi_shot:
			var offset := (i - (multi_shot - 1) * 0.5) * SALVO_SPREAD
			shots.append([origin, dir.rotated(Vector3.UP, offset)])
	AudioManager.sfx("shoot", -14.0)
	return shots

func _lose_hp(amount: float) -> void:
	if immortal:
		return
	hp -= amount
	if hp <= 0.0:
		die()

## Dégâts ordinaires : absorbés par le bouclier, puis les PV. Sans effet
## pendant l'invulnérabilité (dash ou instants qui suivent un coup).
func take_damage(amount: float) -> void:
	if not alive or invuln > 0.0:
		return
	invuln = HIT_INVULN
	since_damage = 0.0
	var left := amount
	if shield > 0.0:
		var absorbed := minf(shield, left)
		shield -= absorbed
		left -= absorbed
		_shield_flash = 1.0
	if left > 0.0:
		_hurt_flash = 1.0
	AudioManager.sfx("player_hurt", -3.0)
	EventBus.screen_shake_requested.emit(0.8)
	EventBus.player_hurt.emit()
	_lose_hp(left)

## Embrasement (squelette de feu) : dégâts continus tant que `burn_time`
## court, sans passer par le bouclier ; seule l'invulnérabilité l'empêche de
## prendre au moment de l'impact.
func ignite(dps: float, duration: float) -> void:
	if not alive or invuln > 0.0:
		return
	burn_dps = dps
	burn_time = maxf(burn_time, duration)

func die() -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	burn_time = 0.0
	AudioManager.sfx("game_over")
	EventBus.player_died.emit()
