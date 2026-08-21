class_name Titan
extends BossBase
## Titan de la Mort (vague 20) : cinq phases, l'arsenal du Colosse Putréfié plus
## la faux au corps-à-corps, la téléportation et la charge.
##
## Attaque ultime : dès qu'il tombe à 1 % de vie en phase 5, il devient
## totalement immunisé pendant 10 s, cesse toute autre attaque, perd son
## bouclier, se téléporte à distance du joueur puis lâche une énorme boule de
## feu. Sans ce recalage, collée au joueur, elle le touchait dans la frame du
## tir sans jamais être visible. Elle s'esquive en se déplaçant, pas en dashant.

const PHASE_HP: Array[float] = [1000.0, 1300.0, 1600.0, 1900.0, 2300.0]

const ULTIMATE_INVULN := 10.0
const ULTIMATE_CHARGE := 3.0
const ULTIMATE_RANGE := 420.0
const ULTIMATE_RADIUS := 46.0
const ULTIMATE_SPEED := 690.0      # v1 : 11.5 px/frame
const ULTIMATE_TRIGGER := 0.01     # 1 % de la barre de phase 5

const SCYTHE_INTERVAL := 2.4
const SCYTHE_RANGE := 130.0
const SLAM_INTERVAL := 3.6
const SLAM_RADIUS := 165.0
const POISON_INTERVAL := 2.0
const TELEPORT_INTERVAL := 4.0
const CHARGE_INTERVAL := 5.5
const BARRAGE_INTERVAL := 6.0
const SUMMON_INTERVAL := 5.0
const FISSURE_INTERVAL := 7.0

var _scythe_cd := SCYTHE_INTERVAL
var _slam_cd := SLAM_INTERVAL
var _poison_cd := POISON_INTERVAL
var _teleport_cd := TELEPORT_INTERVAL
var _charge_cd := CHARGE_INTERVAL
var _barrage_cd := BARRAGE_INTERVAL
var _summon_cd := SUMMON_INTERVAL
var _fissure_cd := FISSURE_INTERVAL
var _drain_cd := 0.0

var ultimate_state := "none"   ## none | charging | done
var _ultimate_invuln := 0.0
var _ultimate_charge := 0.0

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "titan"
	display_name = "Titan de la Mort"
	radius = 68.0
	xp_color = Color(0.72, 0.24, 0.28)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

func _sprite_name() -> String:
	return "titan"

## Raccourci de test conservé de la v1 : le Titan démarre en phase 5 à 5 % de vie.
func jump_to_final_stand() -> void:
	phase = PHASE_HP.size() - 1
	max_hp = phase_hp[phase]
	hp = max_hp * 0.05
	speed_mul = 1.0 + 0.15 * phase
	damage_mul = 1.0 + 0.2 * phase
	EventBus.boss_phase_changed.emit(phase + 1, phase_count())
	EventBus.boss_hp_changed.emit(hp / max_hp)

func _behaviour(delta: float) -> void:
	if ultimate_state == "charging":
		_tick_ultimate(delta)
		return
	_keep_range(delta, 190.0)
	_scythe_cd -= delta
	if _scythe_cd <= 0.0:
		_scythe_cd = SCYTHE_INTERVAL
		_scythe()
	_slam_cd -= delta
	if _slam_cd <= 0.0:
		_slam_cd = SLAM_INTERVAL
		_ground_slam()
	_poison_cd -= delta
	if _poison_cd <= 0.0:
		_poison_cd = POISON_INTERVAL
		_shoot_at_player(260.0, hit_damage() * 0.4, 9.0,
			Color(0.55, 0.85, 0.3), "proj_poison", true)
	if phase >= 1:
		_teleport_cd -= delta
		if _teleport_cd <= 0.0:
			_teleport_cd = TELEPORT_INTERVAL
			_teleport()
		_charge_cd -= delta
		if _charge_cd <= 0.0:
			_charge_cd = CHARGE_INTERVAL
			_charge()
		_barrage_cd -= delta
		if _barrage_cd <= 0.0:
			_barrage_cd = BARRAGE_INTERVAL
			_barrage()
	if phase >= 3:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = SUMMON_INTERVAL
			_summon("res://scenes/enemies/risen.gd", "risen", 3, 8)
		_fissure_cd -= delta
		if _fissure_cd <= 0.0:
			_fissure_cd = FISSURE_INTERVAL
			_fissures()
	if phase >= 4:
		_lifedrain(delta)

func _scythe() -> void:
	if global_position.distance_to(player.global_position) > SCYTHE_RANGE:
		return
	_telegraph_strike(global_position, SCYTHE_RANGE, hit_damage(), 0.45,
		Color(0.9, 0.2, 0.25), 9.0)

func _ground_slam() -> void:
	_telegraph_strike(player.global_position, SLAM_RADIUS, hit_damage() * 0.8, 0.8,
		Color(1.0, 0.4, 0.3), 14.0)

func _teleport() -> void:
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	global_position = player.global_position + dir * 70.0
	_clamp_inside()
	EventBus.screen_shake_requested.emit(6.0)

func _charge() -> void:
	var dir := (player.global_position - global_position).normalized()
	global_position += dir * 180.0
	_clamp_inside()
	if global_position.distance_to(player.global_position) <= radius + 30.0:
		player.take_damage(hit_damage() * 1.1)

func _barrage() -> void:
	for i in 12:
		_shoot_dir(Vector2.RIGHT.rotated(TAU * i / 12.0), 200.0,
			hit_damage() * 0.35, 8.0, Color(0.9, 0.4, 0.9), "proj_orb")

func _fissures() -> void:
	var size := get_viewport_rect().size
	for i in 4:
		var at := Vector2(randf_range(80.0, size.x - 80.0), randf_range(80.0, size.y - 80.0))
		_telegraph_strike(at, 110.0, hit_damage() * 0.6, 1.0 + i * 0.2,
			Color(0.8, 0.5, 0.2), 6.0)

func _lifedrain(delta: float) -> void:
	_drain_cd = maxf(0.0, _drain_cd - delta)
	if _drain_cd > 0.0:
		return
	if global_position.distance_to(player.global_position) > radius + 40.0:
		return
	_drain_cd = 1.0
	var amount := hit_damage() * 0.35
	player.take_damage(amount)
	hp = minf(max_hp, hp + amount)
	EventBus.boss_hp_changed.emit(clampf(hp / max_hp, 0.0, 1.0))

func _clamp_inside() -> void:
	var size := get_viewport_rect().size
	global_position.x = clampf(global_position.x, radius, size.x - radius)
	global_position.y = clampf(global_position.y, radius, size.y - radius)

# --- Attaque ultime -----------------------------------------------------

## En phase finale, tant que l'ultime n'a pas eu lieu, la barre ne peut pas
## descendre sous le seuil : un coup assez fort la traverserait sinon d'un trait
## et le Titan mourrait sans jamais lancer son attaque.
func take_damage(amount: float) -> void:
	if ultimate_state == "none" and alive and phase == PHASE_HP.size() - 1:
		var floor_hp := max_hp * ULTIMATE_TRIGGER
		if hp - amount <= floor_hp:
			super(maxf(0.0, hp - floor_hp))
			if alive:
				hp = floor_hp
				EventBus.boss_hp_changed.emit(hp / max_hp)
				_begin_ultimate()
			return
	super(amount)

func _begin_ultimate() -> void:
	ultimate_state = "charging"
	immune = true
	_ultimate_invuln = ULTIMATE_INVULN
	_ultimate_charge = ULTIMATE_CHARGE
	# Toute autre attaque cesse : les cooldowns sont repoussés au-delà de l'ultime.
	for prop in ["_scythe_cd", "_slam_cd", "_poison_cd", "_teleport_cd",
			"_charge_cd", "_barrage_cd", "_summon_cd", "_fissure_cd"]:
		set(prop, ULTIMATE_INVULN + 5.0)
	_anchor_for_ultimate()
	if GameState.smoke_test:
		print("[smoke] Titan : ultime amorcée à %.0f px du joueur"
			% global_position.distance_to(player.global_position))
	AudioManager.sfx("titan_charge")
	EventBus.screen_shake_requested.emit(20.0)
	EventBus.float_text_requested.emit(
		global_position, "ATTAQUE ULTIME", Color(1.0, 0.35, 0.15))

## Recale le Titan à distance du joueur : collé à lui ou plaqué contre un bord,
## la boule le touchait dans la frame du tir sans jamais être visible.
func _anchor_for_ultimate() -> void:
	var size := get_viewport_rect().size
	var best := global_position
	var best_score := -1.0
	for i in 16:
		var candidate := player.global_position + Vector2.RIGHT.rotated(TAU * i / 16.0) * ULTIMATE_RANGE
		if candidate.x < radius or candidate.x > size.x - radius:
			continue
		if candidate.y < radius or candidate.y > size.y - radius:
			continue
		var score := minf(minf(candidate.x, size.x - candidate.x),
			minf(candidate.y, size.y - candidate.y))
		if score > best_score:
			best_score = score
			best = candidate
	global_position = best

func _tick_ultimate(delta: float) -> void:
	_ultimate_invuln = maxf(0.0, _ultimate_invuln - delta)
	# Pulse de charge : on éclaircit vers le blanc surexposé, jamais en dessous
	# de 1 — un canal négatif rendrait le Titan noir.
	var pulse := 0.5 + 0.5 * sin(_ultimate_charge * 12.0)
	_visual.modulate = Color(1.0, 1.0, 1.0).lerp(Color(2.6, 1.1, 0.7), pulse)
	if _ultimate_charge > 0.0:
		_ultimate_charge -= delta
		if _ultimate_charge <= 0.0:
			_launch_ultimate()
	if _ultimate_invuln <= 0.0:
		ultimate_state = "done"
		immune = false
		_visual.modulate = Color.WHITE
		# Le combat reprend normalement une fois l'ultime passée.
		_scythe_cd = SCYTHE_INTERVAL
		_slam_cd = SLAM_INTERVAL
		_poison_cd = POISON_INTERVAL
		_teleport_cd = TELEPORT_INTERVAL
		_charge_cd = CHARGE_INTERVAL
		_barrage_cd = BARRAGE_INTERVAL
		_summon_cd = SUMMON_INTERVAL
		_fissure_cd = FISSURE_INTERVAL

func _launch_ultimate() -> void:
	var dir := (player.global_position - global_position).normalized()
	var ball := EnemyProjectile.new()
	ball.setup(global_position, dir, ULTIMATE_SPEED, 9999.0, ULTIMATE_RADIUS,
		Color(1.0, 0.55, 0.15), "proj_ultimate")
	ball.ultimate = true
	get_parent().add_child(ball)
	if GameState.smoke_test:
		print("[smoke] Titan : boule ultime lancée")
	AudioManager.sfx("titan_ultimate")
	EventBus.screen_shake_requested.emit(26.0)
