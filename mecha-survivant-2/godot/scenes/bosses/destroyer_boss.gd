class_name DestroyerBoss
extends BossBase
## Le Destructeur d'univers : boss du niveau spécial, choisi depuis l'écran
## d'accueil. Un géant en combinaison noire technologique, visière jaune et
## symbole au milieu du torse — **ses lasers partent de ces deux points**
## (`VISOR` et `CORE`, décalages depuis le centre du boss).
##
## Cinq phases, chacune ajoute une attaque à celles d'avant et resserre les
## cadences :
##   1. rayon de visière visé sur le mech ;
##   2. éventail de trois rayons tirés du symbole ;
##   3. étoile de huit rayons du symbole, visière en double tir ;
##   4. balayage de visière et effondrement d'étoiles (zones annoncées) ;
##   5. cage de rayons tournante et spirale d'orbes depuis le symbole.
##
## À sa mort il lâche la gemme dorée (`golden_gem.gd`) ; la ramasser termine
## le jeu. Sans planche `boss_destroyer.png`, il est dessiné en code par
## `Figure` ci-dessous — et c'est ce dessin qui fixe `VISOR` et `CORE`. Une
## planche déposée plus tard devra placer visière et symbole aux mêmes hauteurs.

const PHASE_HP: Array[float] = [2800.0, 3400.0, 4000.0, 4800.0, 5800.0]

const VISOR := Vector2(0.0, -62.0)
const CORE := Vector2(0.0, -14.0)
const YELLOW := Color(1.0, 0.86, 0.12)
const YELLOW_CORE := Color(1.0, 0.97, 0.6)

const VISOR_INTERVAL := 2.8
const FAN_INTERVAL := 4.6
const STAR_INTERVAL := 6.5
const SWEEP_INTERVAL := 7.5
const COLLAPSE_INTERVAL := 5.5
const CAGE_INTERVAL := 6.0
const SPIRAL_INTERVAL := 3.2

var _visor_cd := 1.5
var _fan_cd := FAN_INTERVAL
var _star_cd := 2.5
var _sweep_cd := 3.0
var _collapse_cd := COLLAPSE_INTERVAL
var _cage_cd := 2.0
var _spiral_cd := SPIRAL_INTERVAL
var _spiral_angle := 0.0
var _figure: Figure

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "destroyer"
	display_name = "Le Destructeur d'univers"
	radius = 52.0
	xp_color = Color(0.12, 0.12, 0.16)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

## Sans planche, pas de disque de secours : la silhouette est dessinée par
## `Figure`, enfant du visuel pour hériter de son flash d'impact.
func _shape_kind() -> String:
	return "none" if SpriteOrShape.sheet_texture(_sprite_name()) == null else "circle"

func _on_spawn() -> void:
	if SpriteOrShape.sheet_texture(_sprite_name()) == null:
		_figure = Figure.new()
		_visual.add_child(_figure)
	EventBus.dialogue_requested.emit(display_name,
		"Vingt vagues pour arriver jusqu'ici... Je vais éteindre ton univers, une étoile après l'autre.")

## Les cadences se resserrent de 10 % par phase passée.
func _pace() -> float:
	return 1.0 - 0.1 * phase

func _behaviour(delta: float) -> void:
	_keep_range(delta, 240.0)
	if _figure != null:
		_figure.phase = phase
	_visor_cd -= delta
	if _visor_cd <= 0.0:
		_visor_cd = VISOR_INTERVAL * _pace()
		_visor_shot()
	if phase >= 1:
		_fan_cd -= delta
		if _fan_cd <= 0.0:
			_fan_cd = FAN_INTERVAL * _pace()
			_core_fan()
	if phase >= 2:
		_star_cd -= delta
		if _star_cd <= 0.0:
			_star_cd = STAR_INTERVAL * _pace()
			_core_star(8, 0.0)
	if phase >= 3:
		_sweep_cd -= delta
		if _sweep_cd <= 0.0:
			_sweep_cd = SWEEP_INTERVAL * _pace()
			_visor_sweep()
		_collapse_cd -= delta
		if _collapse_cd <= 0.0:
			_collapse_cd = COLLAPSE_INTERVAL * _pace()
			_star_collapse()
	if phase >= 4:
		_cage_cd -= delta
		if _cage_cd <= 0.0:
			_cage_cd = CAGE_INTERVAL * _pace()
			_core_star(12, 0.45)
		_spiral_cd -= delta
		if _spiral_cd <= 0.0:
			_spiral_cd = SPIRAL_INTERVAL * _pace()
			_core_spiral()

func _on_phase_started(new_phase: int) -> void:
	if GameState.smoke_test:
		print("[smoke] %s : phase %d/%d" % [display_name, new_phase + 1, phase_count()])
	EventBus.float_text_requested.emit(global_position + Vector2(0, -110),
		["", "LE SYMBOLE S'ÉVEILLE", "SURCHARGE", "L'UNIVERS VACILLE", "ANNIHILATION"][new_phase],
		YELLOW)

func _aim_from(origin_offset: Vector2) -> float:
	return (player.global_position - (global_position + origin_offset)).angle()

func _laser(origin_offset: Vector2, angle: float, dmg: float, windup: float,
		firing: float = 0.4, width: float = 18.0, sweep: float = 0.0) -> void:
	var beam := LaserBeam.new()
	beam.source = self
	beam.offset = origin_offset
	beam.angle = angle
	beam.damage = dmg
	beam.windup = windup
	beam.firing = firing
	beam.width = width
	beam.sweep = sweep
	beam.color = YELLOW
	beam.core_color = YELLOW_CORE
	get_parent().add_child(beam)
	if _figure != null:
		_figure.charge(origin_offset == VISOR, windup)

## Phase 1+ : rayon de visière sur le mech. Dès la phase 3, un second rayon
## part peu après, visé là où le mech est allé.
func _visor_shot() -> void:
	_play_attack()
	_laser(VISOR, _aim_from(VISOR), hit_damage() * 0.55, 0.85)
	if phase >= 2:
		get_tree().create_timer(0.55).timeout.connect(func() -> void:
			if alive and player != null and player.alive:
				_laser(VISOR, _aim_from(VISOR), hit_damage() * 0.45, 0.6))

## Phase 2+ : éventail de trois rayons depuis le symbole du torse.
func _core_fan() -> void:
	_play_attack()
	var base := _aim_from(CORE)
	for k in [-1, 0, 1]:
		_laser(CORE, base + 0.32 * k, hit_damage() * 0.45, 0.95)

## Phase 3+ : étoile de rayons à 360° depuis le symbole. Avec `spin`, les
## rayons tournent en tirant — la cage de la dernière phase.
func _core_star(count: int, spin: float) -> void:
	_play_attack()
	var offset := randf() * TAU
	for i in count:
		_laser(CORE, offset + TAU * i / count, hit_damage() * 0.4, 1.1,
			0.9 if spin != 0.0 else 0.4, 14.0, spin)

## Phase 4+ : la visière balaie un arc qui traverse la position du mech.
func _visor_sweep() -> void:
	_play_attack()
	var dir := -1.0 if randf() < 0.5 else 1.0
	_laser(VISOR, _aim_from(VISOR) - 0.9 * dir, hit_damage() * 0.55, 0.9,
		1.3, 20.0, 1.4 * dir)

## Phase 4+ : des étoiles s'effondrent autour du mech — zones annoncées.
func _star_collapse() -> void:
	var view := Level.current.view_rect().grow(-60.0)
	for i in 4:
		var at := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 260.0)
		at = at.clamp(view.position, view.end)
		_telegraph_strike(at, 85.0, hit_damage() * 0.5, 0.8 + i * 0.15, YELLOW, 8.0)

## Phase 5 : spirale d'orbes depuis le symbole.
func _core_spiral() -> void:
	for i in 10:
		_spiral_angle += 0.27
		var p := EnemyProjectile.new()
		p.setup(global_position + CORE, Vector2.RIGHT.rotated(_spiral_angle + TAU * i / 10.0),
			200.0, hit_damage() * 0.3, 8.0, YELLOW, "proj_orb")
		get_parent().add_child(p)

func die() -> void:
	if not alive:
		return
	var drop := Level.current.nearest_free(global_position)
	super()
	# Les rayons et orbes encore en vol ne doivent pas tuer le mech après la
	# victoire : on les retire avec le boss.
	for n in get_parent().get_children():
		if n is LaserBeam or n is EnemyProjectile or n is Telegraph:
			n.queue_free()
	var gem := GoldenGem.new()
	gem.position = drop
	# Différé : la mort remonte de la collision d'une balle (voir WaveManager).
	get_parent().call_deferred("add_child", gem)
	EventBus.dialogue_requested.emit(display_name,
		"Impossible... La gemme... elle ne devait jamais tomber entre tes mains...")


## Silhouette du Destructeur, dessinée en pixels pleins : grand corps en
## combinaison noire, liserés technologiques gris-bleu, visière jaune et
## symbole lumineux au milieu du torse. Visière et symbole s'illuminent
## pendant que leur laser se charge, et brûlent plus fort à chaque phase.
class Figure extends Node2D:
	const SUIT := Color(0.06, 0.06, 0.08)
	const SUIT_HI := Color(0.17, 0.18, 0.23)
	const TRIM := Color(0.32, 0.38, 0.5)
	const OUTLINE := Color(0.0, 0.0, 0.0)

	var phase := 0
	var _t := 0.0
	var _visor_glow := 0.0
	var _core_glow := 0.0

	func charge(visor: bool, duration: float) -> void:
		if visor:
			_visor_glow = maxf(_visor_glow, duration + 0.4)
		else:
			_core_glow = maxf(_core_glow, duration + 0.4)

	func _process(delta: float) -> void:
		_t += delta
		_visor_glow = maxf(0.0, _visor_glow - delta)
		_core_glow = maxf(0.0, _core_glow - delta)
		queue_redraw()

	func _box(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), OUTLINE)
		draw_rect(Rect2(x, y, w, h), c)

	func _draw() -> void:
		var breathe := roundf(sin(_t * 2.0) * 1.5)
		var heat := float(phase) / 4.0
		var glow_col: Color = YELLOW.lerp(Color(1.0, 0.45, 0.1), heat * 0.6)
		# Aura qui grandit avec les phases.
		if phase > 0:
			var a := 0.08 + 0.05 * phase + 0.04 * sin(_t * 5.0)
			draw_circle(Vector2(0, -20), 70.0 + 6.0 * phase, Color(glow_col, a * 0.5))
		# Ombre portée.
		draw_set_transform(Vector2(0, 64), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
		# Jambes et bottes.
		_box(-26, 22, 18, 40, SUIT)
		_box(8, 22, 18, 40, SUIT)
		draw_rect(Rect2(-26, 52, 18, 10), SUIT_HI)
		draw_rect(Rect2(8, 52, 18, 10), SUIT_HI)
		draw_rect(Rect2(-20, 30, 2, 18), TRIM)
		draw_rect(Rect2(18, 30, 2, 18), TRIM)
		# Bras, gantelets.
		_box(-50, -40 + breathe, 14, 56, SUIT)
		_box(36, -40 + breathe, 14, 56, SUIT)
		draw_rect(Rect2(-50, 6 + breathe, 14, 10), SUIT_HI)
		draw_rect(Rect2(36, 6 + breathe, 14, 10), SUIT_HI)
		# Torse et ceinture.
		_box(-36, -46 + breathe, 72, 70 - breathe, SUIT)
		draw_rect(Rect2(-36, 14, 72, 8), SUIT_HI)
		draw_rect(Rect2(-6, 14, 12, 8), TRIM)
		# Épaulières.
		_box(-56, -50 + breathe, 26, 16, SUIT_HI)
		_box(30, -50 + breathe, 26, 16, SUIT_HI)
		draw_rect(Rect2(-54, -48 + breathe, 22, 2), TRIM)
		draw_rect(Rect2(32, -48 + breathe, 22, 2), TRIM)
		# Liserés technologiques du torse.
		draw_rect(Rect2(-30, -38 + breathe, 2, 46), TRIM)
		draw_rect(Rect2(28, -38 + breathe, 2, 46), TRIM)
		draw_rect(Rect2(-30, -38 + breathe, 16, 2), TRIM)
		draw_rect(Rect2(14, -38 + breathe, 16, 2), TRIM)
		draw_rect(Rect2(-30, 6, 60, 2), TRIM)
		# Cou et casque.
		_box(-8, -54 + breathe, 16, 10, SUIT)
		_box(-20, -82 + breathe, 40, 32, SUIT)
		draw_rect(Rect2(-18, -80 + breathe, 36, 4), SUIT_HI)
		# Visière jaune : une fente large, plus vive pendant la charge.
		var vg: float = clampf(_visor_glow, 0.0, 1.0)
		var visor_c: Color = glow_col.lerp(Color.WHITE, vg * 0.6)
		var vy := VISOR.y + breathe
		if vg > 0.0:
			draw_rect(Rect2(-22, vy - 7, 44, 14), Color(visor_c, 0.35 * vg))
		draw_rect(Rect2(-16, vy - 4, 32, 8), visor_c)
		draw_rect(Rect2(-14, vy - 3, 12, 2), Color(1, 1, 1, 0.75))
		# Symbole du torse : losange cerclé, triangle évidé au centre.
		var cg: float = clampf(_core_glow, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_t * (3.0 + phase))
		var core_c: Color = glow_col.lerp(Color.WHITE, cg * 0.6)
		var c := Vector2(0, CORE.y + breathe)
		draw_circle(c, 15.0 + 3.0 * cg, Color(core_c, 0.18 + 0.15 * pulse + 0.3 * cg))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0),
			c + Vector2(0, 12), c + Vector2(-12, 0)]), core_c)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 4),
			c + Vector2(-5, 4)]), SUIT)
		draw_polyline(PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0),
			c + Vector2(0, 12), c + Vector2(-12, 0), c + Vector2(0, -12)]), OUTLINE, 2.0)
