class_name Gravedigger
extends BossBase
## Le Fossoyeur : invoque des créatures de l'ombre en continu et frappe au sol.

const SUMMON_INTERVAL := 3.2
const SLAM_INTERVAL := 4.5
const SLAM_RADIUS := 150.0

var _summon_cd := 2.0
var _slam_cd := SLAM_INTERVAL

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "gravedigger"
	display_name = "Le Fossoyeur"
	xp_color = Color(0.36, 0.30, 0.52)

func _behaviour(delta: float) -> void:
	_keep_range(delta, 200.0)
	_summon_cd -= delta
	if _summon_cd <= 0.0:
		_summon_cd = SUMMON_INTERVAL
		_summon("res://scenes/enemies/shade.gd", "shade", 2, 10)
	_slam_cd -= delta
	if _slam_cd <= 0.0:
		_slam_cd = SLAM_INTERVAL
		_slam()

func _slam() -> void:
	_telegraph_strike(player.global_position, SLAM_RADIUS, hit_damage(), 0.8,
		Color(0.6, 0.4, 0.9))
