class_name PlagueHerald
extends BossBase
## Le Héraut de la Peste : projectiles empoisonnés et flaques d'acide.

const SHOT_INTERVAL := 1.6
const PUDDLE_INTERVAL := 3.0

var _shot_cd := SHOT_INTERVAL
var _puddle_cd := PUDDLE_INTERVAL

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "plague"
	display_name = "Héraut de la Peste"
	xp_color = Color(0.48, 0.72, 0.30)

func _behaviour(delta: float) -> void:
	_keep_range(delta, 260.0)
	_shot_cd -= delta
	if _shot_cd <= 0.0:
		_shot_cd = SHOT_INTERVAL
		for i in 3:
			var dir := (player.global_position - global_position).normalized()
			_shoot_dir(dir.rotated(deg_to_rad((i - 1) * 12.0)), 240.0,
				hit_damage() * 0.45, 9.0, Color(0.55, 0.85, 0.3), "proj_poison", true)
	_puddle_cd -= delta
	if _puddle_cd <= 0.0:
		_puddle_cd = PUDDLE_INTERVAL
		var puddle := GroundHazard.new()
		puddle.position = player.global_position
		puddle.damage_per_second = hit_damage() * 0.5
		get_parent().add_child(puddle)
