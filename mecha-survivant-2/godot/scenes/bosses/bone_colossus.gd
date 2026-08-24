class_name BoneColossus
extends BossBase
## Le Colosse d'os : relève des squelettes, tire un laser et déclenche le
## balayage d'ossements — un secteur qui tourne autour de lui.

const RAISE_INTERVAL := 4.0
const LASER_INTERVAL := 5.0
const SWEEP_INTERVAL := 9.0
const SWEEP_RADIUS := 560.0

var _raise_cd := 2.5
var _laser_cd := LASER_INTERVAL
var _sweep_cd := SWEEP_INTERVAL

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "bone_colossus"
	display_name = "Colosse d'os"
	xp_color = Color(0.86, 0.85, 0.76)

func _behaviour(delta: float) -> void:
	_keep_range(delta, 240.0)
	_raise_cd -= delta
	if _raise_cd <= 0.0:
		_raise_cd = RAISE_INTERVAL
		_summon("res://scenes/enemies/skeleton.gd", "skeleton", 2, 8)
	_laser_cd -= delta
	if _laser_cd <= 0.0:
		_laser_cd = LASER_INTERVAL
		_fire_laser()
	_sweep_cd -= delta
	if _sweep_cd <= 0.0:
		_sweep_cd = SWEEP_INTERVAL
		_bone_sweep()

func _fire_laser() -> void:
	var beam := LaserBeam.new()
	beam.source = self
	beam.angle = (player.global_position - global_position).angle()
	beam.damage = hit_damage()
	get_parent().add_child(beam)

func _bone_sweep() -> void:
	var sweep := BoneSweep.new()
	sweep.source = self
	sweep.radius = SWEEP_RADIUS
	sweep.damage = hit_damage()
	get_parent().add_child(sweep)
