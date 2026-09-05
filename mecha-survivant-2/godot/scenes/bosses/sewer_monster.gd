class_name SewerMonster
extends BossBase
## Monstre des Égouts (vague 10) : crachats empoisonnés, flaques toxiques et
## invocation de revenants tirés de la vase. En phase 2, un anneau de geysers
## nauséabonds encercle le joueur pour lui forcer une brèche à repérer.

const SHOT_INTERVAL := 1.8
const PUDDLE_INTERVAL := 3.4
const SUMMON_INTERVAL := 4.5
const RING_INTERVAL := 5.0
const RING_COUNT := 6
const RING_RADIUS := 150.0

var _shot_cd := SHOT_INTERVAL
var _puddle_cd := 2.0
var _summon_cd := SUMMON_INTERVAL
var _ring_cd := 3.0

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "sewer_monster"
	display_name = "Monstre des Égouts"
	radius = 48.0
	xp_color = Color(0.42, 0.58, 0.30)
	# Deux phases pour un combat plus long qu'avant (la phase unique était
	# héritée par défaut de BossBase).
	phase_hp = [900.0 + 300.0 * tier, 700.0 + 300.0 * tier]
	max_hp = phase_hp[0]
	hp = max_hp

func _behaviour(delta: float) -> void:
	_keep_range(delta, 230.0)
	_shot_cd -= delta
	if _shot_cd <= 0.0:
		_shot_cd = SHOT_INTERVAL
		var spread := 5 if phase >= 1 else 3
		for i in spread:
			var dir := (player.global_position - global_position).normalized()
			_shoot_dir(dir.rotated(deg_to_rad((i - (spread - 1) / 2.0) * 12.0)), 230.0,
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
	if phase >= 1:
		_ring_cd -= delta
		if _ring_cd <= 0.0:
			_ring_cd = RING_INTERVAL
			_sewage_ring()

## Anneau de geysers de vase centré sur le joueur : mieux vaut repérer une
## brèche avant l'impact que fuir tout droit.
func _sewage_ring() -> void:
	var center := player.global_position
	for i in RING_COUNT:
		var at := center + Vector2.RIGHT.rotated(TAU * i / RING_COUNT) * RING_RADIUS
		_telegraph_strike(at, 55.0, hit_damage() * 0.5, 0.9, Color(0.4, 0.6, 0.25), 6.0)
