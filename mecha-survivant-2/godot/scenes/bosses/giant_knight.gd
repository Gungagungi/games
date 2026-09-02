class_name GiantKnight
extends BossBase
## Chevalier Géant (vague 5) : garde le corps-à-corps, alterne coup d'estoc
## téléphoné et charge frontale.

const SLAM_INTERVAL := 3.4
const SLAM_RADIUS := 130.0
const CHARGE_INTERVAL := 5.0
const CHARGE_DISTANCE := 220.0

var _slam_cd := 1.6
var _charge_cd := CHARGE_INTERVAL

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "giant_knight"
	display_name = "Chevalier Géant"
	radius = 50.0
	xp_color = Color(0.55, 0.58, 0.65)

func _behaviour(delta: float) -> void:
	_keep_range(delta, 140.0)
	_slam_cd -= delta
	if _slam_cd <= 0.0:
		_slam_cd = SLAM_INTERVAL
		_telegraph_strike(player.global_position, SLAM_RADIUS, hit_damage(), 0.6,
			Color(0.8, 0.8, 0.9), 12.0)
	_charge_cd -= delta
	if _charge_cd <= 0.0:
		_charge_cd = CHARGE_INTERVAL
		_charge()

func _charge() -> void:
	_play_attack()
	var dir := (player.global_position - global_position).normalized()
	global_position += dir * CHARGE_DISTANCE
	_clamp_inside()
	if global_position.distance_to(player.global_position) <= radius + 30.0:
		player.take_damage(hit_damage() * 1.2)

func _clamp_inside() -> void:
	var size := get_viewport_rect().size
	global_position.x = clampf(global_position.x, radius, size.x - radius)
	global_position.y = clampf(global_position.y, radius, size.y - radius)
