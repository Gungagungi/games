class_name Skeleton
extends EnemyBase
## Squelette archer : s'approche jusqu'à portée puis décoche des flèches.

const RANGE := 260.0
const SHOT_INTERVAL := 2.0
const ARROW_DAMAGE := 4.0

var _shot_cd := 1.0

func _shape_kind() -> String:
	return "square"

func _behaviour(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if dist > RANGE:
		_chase(delta)
	elif dist < RANGE * 0.6:
		_chase(delta, -0.6)
	_shot_cd -= delta
	if _shot_cd <= 0.0 and dist <= RANGE:
		_shot_cd = SHOT_INTERVAL
		_shoot()

func _shoot() -> void:
	var dir := (player.global_position - global_position).normalized()
	var arrow := EnemyProjectile.new()
	arrow.setup(global_position, dir, 300.0, ARROW_DAMAGE, 5.0, Color(0.85, 0.86, 0.80), "proj_arrow")
	get_parent().add_child(arrow)
