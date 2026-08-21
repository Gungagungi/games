class_name MegaBoss
extends BossBase
## Colosse Putréfié (vague 15) : trois phases, barre remise à plein à chaque
## passage. Bouclier d'énergie qui le rend immunisé le temps d'une salve
## d'orbes, et ponction de vie au contact en phase 3.

const PHASE_HP: Array[float] = [900.0, 1300.0, 1900.0]

const SLAM_INTERVAL := 4.0
const POISON_INTERVAL := 2.2
const SUMMON_INTERVAL := 5.0
const SHIELD_INTERVAL := 8.0
const SHIELD_DURATION := 2.6
const SLAM_RADIUS := 165.0

var _slam_cd := SLAM_INTERVAL
var _poison_cd := POISON_INTERVAL
var _summon_cd := SUMMON_INTERVAL
var _shield_cd := SHIELD_INTERVAL
var _shield_left := 0.0
var _drain_cd := 0.0

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "megaboss"
	display_name = "Colosse Putréfié"
	radius = 56.0
	xp_color = Color(0.55, 0.68, 0.32)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

func _sprite_name() -> String:
	return "megaboss"

func _behaviour(delta: float) -> void:
	_tick_shield(delta)
	_keep_range(delta, 220.0)
	_slam_cd -= delta
	if _slam_cd <= 0.0:
		_slam_cd = SLAM_INTERVAL
		_ground_slam()
	_poison_cd -= delta
	if _poison_cd <= 0.0:
		_poison_cd = POISON_INTERVAL
		_shoot_at_player(250.0, hit_damage() * 0.45, 9.0,
			Color(0.55, 0.85, 0.3), "proj_poison", true)
	if phase >= 1:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = SUMMON_INTERVAL
			_summon("res://scenes/enemies/risen.gd", "risen", 2, 6)
		_shield_cd -= delta
		if _shield_cd <= 0.0:
			_shield_cd = SHIELD_INTERVAL
			_raise_shield()
	if phase >= 2:
		_lifedrain(delta)

func _tick_shield(delta: float) -> void:
	if _shield_left <= 0.0:
		return
	_shield_left -= delta
	if _shield_left <= 0.0:
		immune = false
		modulate = Color.WHITE

## Bouclier : immunité totale le temps d'une salve de cinq orbes.
func _raise_shield() -> void:
	_shield_left = SHIELD_DURATION
	immune = true
	modulate = Color(0.6, 0.9, 1.2)
	for i in 5:
		var dir := (player.global_position - global_position).normalized()
		_shoot_dir(dir.rotated(deg_to_rad((i - 2) * 15.0)), 210.0,
			hit_damage() * 0.4, 8.0, Color(0.5, 0.9, 1.0), "proj_orb")

func _ground_slam() -> void:
	_telegraph_strike(player.global_position, SLAM_RADIUS, hit_damage() * 0.8, 0.9,
		Color(1.0, 0.4, 0.3), 14.0)

## Ponction de vie passive : au contact, le boss se soigne de ce qu'il inflige.
func _lifedrain(delta: float) -> void:
	_drain_cd = maxf(0.0, _drain_cd - delta)
	if _drain_cd > 0.0:
		return
	if global_position.distance_to(player.global_position) > radius + 40.0:
		return
	_drain_cd = 1.0
	var amount := hit_damage() * 0.3
	player.take_damage(amount)
	hp = minf(max_hp, hp + amount)
	EventBus.boss_hp_changed.emit(clampf(hp / max_hp, 0.0, 1.0))

func _on_phase_started(_new_phase: int) -> void:
	_shield_left = 0.0
	immune = false
	modulate = Color.WHITE
