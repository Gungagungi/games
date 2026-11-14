class_name CrystalBoss
extends BossBase
## Le Cristal : mini-boss d'entraînement, proposé une fois la gemme dorée
## ramassée. Pas très dur, deux phases, et une seule arme — des lasers tirés
## vite et à répétition depuis son cœur. Il faut bouger régulièrement.
##
##   1. doré : rafales de trois rayons visés sur le mech, un par un ;
##   2. rouge : le cristal s'embrase, les rafales s'allongent, chaque tir
##      devient un éventail de trois rayons, et la charge raccourcit.
##
## Sa mort émet `EventBus.crystal_destroyed` (en plus de `boss_defeated`) :
## `main.gd` affiche « Bravo, tu as détruit le cristal » et propose de le
## recombattre ou de quitter l'arène. Dessiné en code par `Shard`, sans
## planche ni disque de secours.

const PHASE_HP: Array[float] = [1500.0, 1900.0]

const GOLD := Color(1.0, 0.82, 0.25)
const GOLD_CORE := Color(1.0, 0.96, 0.7)
const RED := Color(1.0, 0.22, 0.2)
const RED_CORE := Color(1.0, 0.75, 0.65)

## Par phase : pause entre deux rafales, tirs par rafale, écart entre tirs,
## charge d'un rayon, rayons par tir (éventail) et leur écart angulaire.
const BURST_INTERVAL: Array[float] = [1.7, 1.1]
const BURST_SHOTS: Array[int] = [3, 4]
const SHOT_GAP: Array[float] = [0.32, 0.24]
const WINDUP: Array[float] = [0.55, 0.38]
const FAN: Array[int] = [1, 3]
const FAN_SPREAD := 0.3

var _burst_cd := 1.5
var _shots_left := 0
var _shot_cd := 0.0
var _shard: Shard

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "crystal"
	display_name = "Le Cristal"
	radius = 40.0
	xp_color = GOLD
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

func _shape_kind() -> String:
	return "none"

func _on_spawn() -> void:
	_shard = Shard.new()
	_visual.add_child(_shard)

## Il flotte à distance et ne cherche pas le contact : le danger, ce sont
## ses rayons.
func _deals_no_contact_damage() -> bool:
	return true

func _behaviour(delta: float) -> void:
	_keep_range(delta * 0.6, 280.0)
	if _shots_left > 0:
		_shot_cd -= delta
		if _shot_cd <= 0.0:
			_shot_cd = SHOT_GAP[phase]
			_shots_left -= 1
			_fire()
		return
	_burst_cd -= delta
	if _burst_cd <= 0.0:
		_burst_cd = BURST_INTERVAL[phase]
		_shots_left = BURST_SHOTS[phase]
		_shot_cd = 0.0

func _fire() -> void:
	var base := (player.global_position - global_position).angle()
	var n: int = FAN[phase]
	for i in n:
		var k := float(i) - float(n - 1) / 2.0
		var beam := LaserBeam.new()
		beam.source = self
		beam.angle = base + FAN_SPREAD * k
		beam.damage = hit_damage() * 0.3
		beam.windup = WINDUP[phase]
		beam.firing = 0.25
		beam.width = 12.0
		beam.color = RED if phase > 0 else GOLD
		beam.core_color = RED_CORE if phase > 0 else GOLD_CORE
		get_parent().add_child(beam)
	if _shard != null:
		_shard.pulse()

func _on_phase_started(new_phase: int) -> void:
	_shots_left = 0
	_burst_cd = 1.2
	xp_color = RED
	if _shard != null:
		_shard.red = true
	if GameState.smoke_test:
		print("[smoke] %s : phase %d/%d" % [display_name, new_phase + 1, phase_count()])
	EventBus.float_text_requested.emit(global_position + Vector2(0, -80),
		"LE CRISTAL ROUGEOIE", RED)

func die() -> void:
	if not alive:
		return
	super()
	# Les rayons en charge ne doivent pas toucher le mech après la victoire.
	for n in get_parent().get_children():
		if n is LaserBeam:
			n.queue_free()
	EventBus.crystal_destroyed.emit()


## Le cristal dessiné : la gemme dorée en grand, taillée en losange, qui
## flotte, tourne ses éclats et s'illumine à chaque tir. Rouge en phase 2.
class Shard extends Node2D:
	const SIZE := 42.0

	var red := false
	var _t := 0.0
	var _flash := 0.0

	func pulse() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var main := CrystalBoss.RED if red else CrystalBoss.GOLD
		var light := CrystalBoss.RED_CORE if red else CrystalBoss.GOLD_CORE
		var dark := main.darkened(0.4)
		var edge := main.darkened(0.7)
		var bob := Vector2(0.0, sin(_t * 2.5) * 6.0)
		var glow := 0.5 + 0.5 * sin(_t * (6.0 if red else 3.0))
		draw_circle(bob, SIZE * 2.0, Color(main, 0.08 + 0.06 * glow + 0.15 * _flash))
		draw_circle(bob, SIZE * 1.4, Color(main, 0.14 + 0.08 * glow))
		for i in 6:
			var a := _t * (2.2 if red else 1.2) + TAU * i / 6.0
			var at := bob + Vector2.RIGHT.rotated(a) * SIZE * 1.7
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(light, 0.85))
		var top := bob + Vector2(0, -SIZE)
		var bottom := bob + Vector2(0, SIZE * 1.15)
		var left := bob + Vector2(-SIZE * 0.85, -SIZE * 0.2)
		var right := bob + Vector2(SIZE * 0.85, -SIZE * 0.2)
		var mid := bob + Vector2(0, -SIZE * 0.2)
		draw_colored_polygon(PackedVector2Array([top, right, mid]), light)
		draw_colored_polygon(PackedVector2Array([top, mid, left]), main)
		draw_colored_polygon(PackedVector2Array([left, mid, bottom]), dark)
		draw_colored_polygon(PackedVector2Array([mid, right, bottom]), main)
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), edge, 3.0)
		draw_line(left, right, Color(edge, 0.6), 1.5)
		draw_line(mid, bottom, Color(edge, 0.4), 1.5)
		# Cœur d'où partent les rayons : il s'allume à chaque tir.
		draw_circle(Vector2.ZERO, 6.0 + 6.0 * _flash, Color(1, 1, 1, 0.5 + 0.5 * _flash))
		draw_circle(bob + Vector2(-SIZE * 0.25, -SIZE * 0.5), 4.0, Color(1, 1, 1, glow))
