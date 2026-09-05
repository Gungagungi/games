class_name GalaxyBoss
extends BossBase
## Boss Galaxie : le vrai combat final, à la vague 20 (voir `titan_decoy.gd`,
## désormais un simple leurre comique de la vague 1, sans lien avec lui).
## Trois phases : barrage d'étoiles en spirale, météores téléphonés,
## téléportation laissant une traînée explosive, et supernova finale à 360°
## en dernière phase.

const PHASE_HP: Array[float] = [1800.0, 2300.0, 3000.0]

const BARRAGE_INTERVAL := 4.0
const METEOR_INTERVAL := 3.2
const SUMMON_INTERVAL := 5.0
const TELEPORT_INTERVAL := 4.5
const SUPERNOVA_INTERVAL := 6.0

var _barrage_cd := 2.0
var _meteor_cd := METEOR_INTERVAL
var _summon_cd := SUMMON_INTERVAL
var _teleport_cd := TELEPORT_INTERVAL
var _supernova_cd := SUPERNOVA_INTERVAL
var _spiral_angle := 0.0

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "galaxy_boss"
	display_name = "Boss Galaxie"
	radius = 58.0
	xp_color = Color(0.45, 0.35, 0.85)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

func _behaviour(delta: float) -> void:
	_keep_range(delta, 260.0)
	_barrage_cd -= delta
	if _barrage_cd <= 0.0:
		_barrage_cd = BARRAGE_INTERVAL
		_star_barrage()
	_meteor_cd -= delta
	if _meteor_cd <= 0.0:
		_meteor_cd = METEOR_INTERVAL
		_meteors()
	if phase >= 1:
		_teleport_cd -= delta
		if _teleport_cd <= 0.0:
			_teleport_cd = TELEPORT_INTERVAL
			_teleport()
	if phase >= 2:
		_summon_cd -= delta
		if _summon_cd <= 0.0:
			_summon_cd = SUMMON_INTERVAL
			_summon("res://scenes/enemies/shade.gd", "shade", 3, 10)
		_supernova_cd -= delta
		if _supernova_cd <= 0.0:
			_supernova_cd = SUPERNOVA_INTERVAL
			_supernova()

func _star_barrage() -> void:
	_play_attack()
	for i in 8:
		_spiral_angle += 0.35
		_shoot_dir(Vector2.RIGHT.rotated(_spiral_angle + TAU * i / 8.0), 190.0,
			hit_damage() * 0.35, 8.0, Color(0.65, 0.5, 1.0), "proj_orb")

func _meteors() -> void:
	var size := get_viewport_rect().size
	for i in 3:
		var at := Vector2(randf_range(80.0, size.x - 80.0), randf_range(80.0, size.y - 80.0))
		_telegraph_strike(at, 100.0, hit_damage() * 0.6, 0.9 + i * 0.15,
			Color(0.7, 0.4, 1.0), 8.0)

## Le boss se téléporte et laisse une traînée qui explose là où il se
## tenait : un croc-en-jambe pour qui le suit encore du regard.
func _teleport() -> void:
	var old_pos := global_position
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	global_position = player.global_position + dir * 220.0
	_clamp_inside()
	EventBus.screen_shake_requested.emit(6.0)
	_telegraph_strike(old_pos, 90.0, hit_damage() * 0.5, 0.5, Color(0.6, 0.3, 0.9), 8.0)

## Supernova à 360°, réservée à la dernière phase.
func _supernova() -> void:
	_play_attack()
	for i in 16:
		_shoot_dir(Vector2.RIGHT.rotated(TAU * i / 16.0), 220.0, hit_damage() * 0.45,
			10.0, Color(0.8, 0.6, 1.0), "proj_orb")
	EventBus.screen_shake_requested.emit(10.0)

func _clamp_inside() -> void:
	var size := get_viewport_rect().size
	global_position.x = clampf(global_position.x, radius, size.x - radius)
	global_position.y = clampf(global_position.y, radius, size.y - radius)
