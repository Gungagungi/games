class_name SewerMonster
extends BossBase
## Monstre des Égouts (vague 10) : crachats empoisonnés, flaques toxiques et
## invocation de revenants tirés de la vase.

const SHOT_INTERVAL := 1.8
const PUDDLE_INTERVAL := 3.4
const SUMMON_INTERVAL := 4.5

var _shot_cd := SHOT_INTERVAL
var _puddle_cd := 2.0
var _summon_cd := SUMMON_INTERVAL

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "sewer_monster"
	display_name = "Monstre des Égouts"
	radius = 48.0
	xp_color = Color(0.42, 0.58, 0.30)

func _behaviour(delta: float) -> void:
	_keep_range(delta, 230.0)
	_shot_cd -= delta
	if _shot_cd <= 0.0:
		_shot_cd = SHOT_INTERVAL
		for i in 3:
			var dir := (player.global_position - global_position).normalized()
			_shoot_dir(dir.rotated(deg_to_rad((i - 1) * 14.0)), 230.0,
				hit_damage() * 0.4, 9.0, Color(0.45, 0.65, 0.25), "proj_poison", true)
	_puddle_cd -= delta
	if _puddle_cd <= 0.0:
		_puddle_cd = PUDDLE_INTERVAL
		var puddle := GroundHazard.new()
		puddle.position = player.global_position
		puddle.damage_per_second = hit_damage() * 0.45
		puddle.color = Color(0.35, 0.5, 0.2)
		get_parent().add_child(puddle)
	_summon_cd -= delta
	if _summon_cd <= 0.0:
		_summon_cd = SUMMON_INTERVAL
		_summon("res://scenes/enemies/risen.gd", "risen", 3, 8)
