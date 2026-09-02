class_name ZombieTitan
extends BossBase
## Zombie Titan (vague 15) : colosse putréfié en deux phases. Invoque des
## morts-vivants en masse et draine la vie au contact une fois enragé.

const PHASE_HP: Array[float] = [900.0, 1400.0]

const SLAM_INTERVAL := 3.6
const SLAM_RADIUS := 170.0
const SUMMON_INTERVAL := 4.2
const POISON_INTERVAL := 2.4

var _slam_cd := SLAM_INTERVAL
var _summon_cd := 2.0
var _poison_cd := POISON_INTERVAL
var _drain_cd := 0.0

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "zombie_titan"
	display_name = "Zombie Titan"
	radius = 60.0
	xp_color = Color(0.38, 0.5, 0.32)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

func _behaviour(delta: float) -> void:
	_keep_range(delta, 200.0)
	_slam_cd -= delta
	if _slam_cd <= 0.0:
		_slam_cd = SLAM_INTERVAL
		_telegraph_strike(player.global_position, SLAM_RADIUS, hit_damage() * 0.85, 0.85,
			Color(0.5, 0.7, 0.3), 15.0)
	_summon_cd -= delta
	if _summon_cd <= 0.0:
		_summon_cd = SUMMON_INTERVAL
		_summon("res://scenes/enemies/zombie.gd", "zombie", 3, 10)
	if phase >= 1:
		_poison_cd -= delta
		if _poison_cd <= 0.0:
			_poison_cd = POISON_INTERVAL
			_shoot_at_player(240.0, hit_damage() * 0.4, 9.0,
				Color(0.55, 0.85, 0.3), "proj_poison", true)
		_lifedrain(delta)

## Ponction de vie passive au contact, comme le Colosse Putréfié de la v1.
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
