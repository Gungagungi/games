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
## Trois attaques « d'arsenal » s'y ajoutent, hors lasers :
##   - dès la phase 1, une lame jaillit de son poignet droit (`WRIST`) : il
##     fonce sur le mech pendant qu'elle sort, puis fauche un arc ;
##   - dès la phase 2, une salve de missiles à tête chercheuse part de ses
##     épaulières (`homing_missile.gd`) ;
##   - dès la phase 3, il envoie des robots qui lancent des boules de métal
##     (`destroyer_robot.gd`), retirés avec lui à sa mort.
##
## Pendant le combat, des potions de soin (`health_potion.gd`) apparaissent
## près du mech toutes les `POTION_INTERVAL` secondes, et une à chaque phase
## franchie — au plus `POTION_CAP` sur la carte.
##
## À sa mort il lâche la gemme dorée (`golden_gem.gd`) ; la ramasser termine
## le jeu. Sans planche `boss_destroyer.png`, il est dessiné en code par
## `Figure` ci-dessous — et c'est ce dessin qui fixe `VISOR` et `CORE`. Une
## planche déposée plus tard devra placer visière et symbole aux mêmes hauteurs.

const PHASE_HP: Array[float] = [2800.0, 3400.0, 4000.0, 4800.0, 5800.0]
## Raccourci « PHASE 5 » de l'écran-titre : part de la barre restante.
const FINAL_PHASE_HP_RATIO := 0.01

const VISOR := Vector2(0.0, -62.0)
const CORE := Vector2(0.0, -14.0)
## Gantelet droit (lame) et épaulières (missiles), calés sur `Figure`.
const WRIST := Vector2(43.0, 12.0)
const SHOULDERS: Array[Vector2] = [Vector2(-43.0, -44.0), Vector2(43.0, -44.0)]
const YELLOW := Color(1.0, 0.86, 0.12)
const YELLOW_CORE := Color(1.0, 0.97, 0.6)

const VISOR_INTERVAL := 2.8
const FAN_INTERVAL := 4.6
const STAR_INTERVAL := 6.5
const SWEEP_INTERVAL := 7.5
const COLLAPSE_INTERVAL := 5.5
const CAGE_INTERVAL := 6.0
const SPIRAL_INTERVAL := 3.2
const BLADE_INTERVAL := 5.0
const MISSILE_INTERVAL := 6.5
const ROBOT_INTERVAL := 10.0
const ROBOT_CAP := 6
const POTION_INTERVAL := 12.0
const POTION_CAP := 3
## Distance au mech d'une potion posée : visible, mais pas sous ses pieds.
const POTION_MIN_DIST := 140.0
const POTION_MAX_DIST := 320.0
## Ruée pendant la sortie de la lame, en multiple de la vitesse de marche.
const LUNGE_SPEED := 3.5

var _visor_cd := 1.5
var _fan_cd := FAN_INTERVAL
var _star_cd := 2.5
var _sweep_cd := 3.0
var _collapse_cd := COLLAPSE_INTERVAL
var _cage_cd := 2.0
var _spiral_cd := SPIRAL_INTERVAL
var _spiral_angle := 0.0
var _blade_cd := 3.5
var _missile_cd := 2.0
var _robot_cd := 1.5
var _lunge := 0.0
var _potion_cd := POTION_INTERVAL
var _figure: Figure
var _final_shortcut := false

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "destroyer"
	display_name = "Le Destructeur d'univers"
	radius = 52.0
	xp_color = Color(0.12, 0.12, 0.16)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

## Raccourci de test, appelé **avant** l'entrée dans l'arbre : dernière phase
## d'emblée, avec les multiplicateurs qu'auraient laissés les quatre passages
## de phase (`advance_phase()`), et 1 % de la barre. Pour voir les attaques
## finales sans livrer tout le combat, et l'achever en deux ou trois tirs.
func skip_to_final_phase() -> void:
	_final_shortcut = true
	var skipped := phase_count() - 1 - phase
	phase = phase_count() - 1
	speed_mul += 0.15 * skipped
	damage_mul += 0.2 * skipped
	max_hp = phase_hp[phase]
	hp = max_hp * FINAL_PHASE_HP_RATIO

## `BossBase._ready()` affiche une barre pleine : le raccourci la corrige.
func _ready() -> void:
	super()
	if _final_shortcut:
		EventBus.boss_hp_changed.emit(hp / max_hp)
		if GameState.smoke_test:
			print("[smoke] %s : raccourci phase %d/%d, %.0f PV"
				% [display_name, phase + 1, phase_count(), hp])

## Sans planche, pas de disque de secours : la silhouette est dessinée par
## `Figure`, enfant du visuel pour hériter de son flash d'impact.
func _shape_kind() -> String:
	return "none" if SpriteOrShape.sheet_texture(_sprite_name()) == null else "circle"

func _on_spawn() -> void:
	if SpriteOrShape.sheet_texture(_sprite_name()) == null:
		_figure = Figure.new()
		_visual.add_child(_figure)
	if _final_shortcut:
		EventBus.dialogue_requested.emit(display_name,
			"Tu me trouves déjà à genoux... Peu importe : je t'emporte avec moi dans l'ANNIHILATION.")
	else:
		EventBus.dialogue_requested.emit(display_name,
			"Trente vagues pour arriver jusqu'ici... Je vais éteindre ton univers, une étoile après l'autre.")

## Les cadences se resserrent de 10 % par phase passée.
func _pace() -> float:
	return 1.0 - 0.1 * phase

func _behaviour(delta: float) -> void:
	if _lunge > 0.0:
		_lunge -= delta
		if global_position.distance_to(player.global_position) > 90.0:
			_chase(delta, speed_mul * LUNGE_SPEED)
	else:
		_keep_range(delta, 240.0)
	if _figure != null:
		_figure.phase = phase
	_potion_cd -= delta
	if _potion_cd <= 0.0:
		_potion_cd = POTION_INTERVAL
		_drop_potion()
	_visor_cd -= delta
	if _visor_cd <= 0.0:
		_visor_cd = VISOR_INTERVAL * _pace()
		_visor_shot()
	_blade_cd -= delta
	if _blade_cd <= 0.0:
		_blade_cd = BLADE_INTERVAL * _pace()
		_wrist_blade()
	if phase >= 1:
		_missile_cd -= delta
		if _missile_cd <= 0.0:
			_missile_cd = MISSILE_INTERVAL * _pace()
			_missile_volley()
		_fan_cd -= delta
		if _fan_cd <= 0.0:
			_fan_cd = FAN_INTERVAL * _pace()
			_core_fan()
	if phase >= 2:
		_star_cd -= delta
		if _star_cd <= 0.0:
			_star_cd = STAR_INTERVAL * _pace()
			_core_star(8, 0.0)
		_robot_cd -= delta
		if _robot_cd <= 0.0:
			_robot_cd = ROBOT_INTERVAL * _pace()
			_send_robots()
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
	if new_phase > 0:
		_drop_potion()
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

## Phase 1+ : la lame sort du poignet pendant qu'il fonce, puis fauche.
func _wrist_blade() -> void:
	_play_attack()
	var blade := WristBlade.new()
	blade.source = self
	blade.offset = WRIST
	blade.damage = hit_damage() * 0.7
	blade.windup = 0.55
	blade.color = YELLOW
	get_parent().add_child(blade)
	_lunge = blade.windup

## Phase 2+ : salve de missiles depuis les épaulières, lancés vers le haut et
## vers l'extérieur pour qu'ils arrivent en courbe. Un de plus par phase.
func _missile_volley() -> void:
	_play_attack()
	if _figure != null:
		_figure.launch()
	var per_side := 1 + phase / 2
	for s in SHOULDERS.size():
		var side := -1.0 if s == 0 else 1.0
		for i in per_side:
			var m := HomingMissile.new()
			m.position = global_position + SHOULDERS[s]
			m.direction = Vector2.UP.rotated(side * (0.5 + 0.35 * i))
			m.damage = hit_damage() * 0.35
			m.speed = 220.0 + 15.0 * phase
			get_parent().add_child(m)

## Phase 3+ : envoie des robots lanceurs de boules de métal, sans dépasser
## `ROBOT_CAP` en jeu.
func _send_robots() -> void:
	var count := mini(2 + phase / 2, ROBOT_CAP - _count_of_type("robot"))
	if count <= 0:
		return
	_play_attack()
	EventBus.float_text_requested.emit(global_position + Vector2(0, -110), "ROBOTS !", YELLOW)
	for i in count:
		var robot := DestroyerRobot.new()
		robot.configure({
			"type": "robot", "max_hp": 70.0 + 15.0 * phase, "speed": 75.0,
			"damage": hit_damage() * 0.2, "radius": 14.0,
			"color": DestroyerRobot.METAL,
		})
		robot.ball_damage = hit_damage() * 0.18
		robot.position = Level.current.nearest_free(
			global_position + Vector2.RIGHT.rotated(TAU * i / count + randf() * 0.5) * 100.0)
		get_parent().add_child(robot)

## Pose une potion de soin sur une case accessible, à distance du mech et
## dans le champ de la caméra pour qu'on la voie arriver.
func _drop_potion() -> void:
	if player == null or get_tree().get_nodes_in_group("potions").size() >= POTION_CAP:
		return
	var view := Level.current.view_rect().grow(-48.0)
	var at := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) \
		* randf_range(POTION_MIN_DIST, POTION_MAX_DIST)
	var potion := HealthPotion.new()
	potion.position = Level.current.nearest_free(at.clamp(view.position, view.end))
	# Différé : peut partir d'un changement de phase, remonté d'une collision.
	get_parent().call_deferred("add_child", potion)

func die() -> void:
	if not alive:
		return
	var drop := Level.current.nearest_free(global_position)
	super()
	# Les rayons et orbes encore en vol ne doivent pas tuer le mech après la
	# victoire : on les retire avec le boss.
	for n in get_parent().get_children():
		if n is LaserBeam or n is EnemyProjectile or n is Telegraph \
				or n is WristBlade or n is HomingMissile:
			n.queue_free()
		elif n is DestroyerRobot:
			# Ses robots s'éteignent avec lui, sans lâcher d'XP.
			n.alive = false
			n.queue_free()
	var gem := GoldenGem.new()
	gem.position = drop
	# Différé : la mort remonte de la collision d'une balle (voir WaveManager).
	get_parent().call_deferred("add_child", gem)
	EventBus.dialogue_requested.emit(display_name,
		"Impossible... La gemme... elle ne devait jamais tomber entre tes mains...")


## Silhouette du Destructeur, dessinée en pixels pleins : un géant en armure
## noire à plaques biseautées (arête claire en haut, ombre en bas), sous une
## cape déchirée qui ondule. Des conduits d'énergie courent du symbole du torse
## vers les membres, une impulsion les parcourt ; visière et symbole
## s'illuminent pendant que leur laser se charge.
##
## L'armure s'abîme au fil des phases : fissures lumineuses (une série de plus
## par phase), vapeur des épaulières dès la phase 2, étincelles dès la phase 3.
## Les points d'ancrage des attaques (`VISOR`, `CORE`, `WRIST`, `SHOULDERS`)
## sont fixes : le dessin s'organise autour, jamais l'inverse.
class Figure extends Node2D:
	const SUIT := Color(0.07, 0.07, 0.09)
	const SUIT_HI := Color(0.17, 0.18, 0.23)
	const UNDER := Color(0.03, 0.03, 0.04)
	const TRIM := Color(0.32, 0.38, 0.5)
	const METAL := Color(0.5, 0.53, 0.6)
	const CAPE := Color(0.2, 0.04, 0.07)
	const CAPE_DARK := Color(0.11, 0.02, 0.04)
	const OUTLINE := Color(0.0, 0.0, 0.0)
	## Fissures, indexées par la phase où elles apparaissent. Chacune : un
	## booléen (partie haute, qui suit la respiration) puis ses points.
	const CRACKS := [
		[],
		[[true, Vector2(-26, -40), Vector2(-20, -34), Vector2(-23, -29)],
			[false, Vector2(-22, 26), Vector2(-17, 32), Vector2(-20, 37)]],
		[[true, Vector2(24, -42), Vector2(18, -36), Vector2(22, -31), Vector2(17, -27)],
			[true, Vector2(-46, -30), Vector2(-41, -22), Vector2(-45, -16)]],
		[[true, Vector2(-12, -80), Vector2(-7, -74), Vector2(-10, -70)],
			[false, Vector2(14, 24), Vector2(20, 31), Vector2(15, 38), Vector2(21, 44)],
			[true, Vector2(40, -28), Vector2(45, -20)]],
		[[true, Vector2(8, 2), Vector2(14, -2), Vector2(20, 4), Vector2(26, 0)],
			[true, Vector2(-30, 4), Vector2(-22, 8), Vector2(-14, 4)],
			[true, Vector2(10, -82), Vector2(14, -76), Vector2(11, -70)]],
	]
	const SPARK_SPOTS: Array[Vector2] = [Vector2(-24, -32), Vector2(22, -30),
		Vector2(-44, -18), Vector2(18, 32), Vector2(-8, -74), Vector2(22, 2)]

	var phase := 0
	var _t := 0.0
	var _visor_glow := 0.0
	var _core_glow := 0.0
	var _pods_glow := 0.0
	## Respiration de la frame en cours, appliquée au haut du corps.
	var _b := 0.0
	var _glow := YELLOW

	func launch() -> void:
		_pods_glow = 0.5

	func charge(visor: bool, duration: float) -> void:
		if visor:
			_visor_glow = maxf(_visor_glow, duration + 0.4)
		else:
			_core_glow = maxf(_core_glow, duration + 0.4)

	func _process(delta: float) -> void:
		_t += delta
		_visor_glow = maxf(0.0, _visor_glow - delta)
		_core_glow = maxf(0.0, _core_glow - delta)
		_pods_glow = maxf(0.0, _pods_glow - delta)
		queue_redraw()

	## Plaque d'armure : contour, aplat, arête claire en haut et à gauche,
	## ombre en bas et à droite. `up` : suit la respiration du haut du corps.
	func _plate(x: float, y: float, w: float, h: float, c: Color, up := true) -> void:
		if up:
			y += _b
		draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), OUTLINE)
		draw_rect(Rect2(x, y, w, h), c)
		draw_rect(Rect2(x, y, w, 2), c.lightened(0.28))
		draw_rect(Rect2(x, y, 1, h), c.lightened(0.14))
		draw_rect(Rect2(x, y + h - 2, w, 2), c.darkened(0.55))
		draw_rect(Rect2(x + w - 1, y, 1, h), c.darkened(0.4))

	func _rivet(x: float, y: float, up := true) -> void:
		if up:
			y += _b
		draw_rect(Rect2(x - 1, y - 1, 3, 3), UNDER)
		draw_rect(Rect2(x - 1, y - 1, 2, 2), METAL)

	## Conduit d'énergie : segment de liseré dont la lueur suit une onde partie
	## du symbole (`dist` : distance au symbole le long du circuit).
	func _conduit(r: Rect2, dist: float, up := true) -> void:
		if up:
			r.position.y += _b
		var wave := maxf(0.0, sin(_t * (4.0 + phase) - dist * 0.09))
		draw_rect(r, TRIM.lerp(_glow, wave * (0.35 + 0.12 * phase)))

	func _draw() -> void:
		_b = roundf(sin(_t * 2.0) * 1.5)
		var heat := float(phase) / 4.0
		_glow = YELLOW.lerp(Color(1.0, 0.45, 0.1), heat * 0.6)
		# Aura qui grandit avec les phases.
		if phase > 0:
			var a := 0.08 + 0.05 * phase + 0.04 * sin(_t * 5.0)
			draw_circle(Vector2(0, -20), 70.0 + 6.0 * phase, Color(_glow, a * 0.5))
		# Ombre portée.
		draw_set_transform(Vector2(0, 64), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 46.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
		_draw_cape()
		_draw_legs()
		_draw_arm(-1.0)
		_draw_arm(1.0)
		_draw_torso()
		_draw_shoulders()
		_draw_head()
		_draw_core()
		_draw_damage()

	## Cape : tombe des épaules derrière le corps, ourlet déchiré qui ondule.
	## Les x de l'ourlet décroissent strictement : le polygone reste simple.
	func _draw_cape() -> void:
		var pts := PackedVector2Array([Vector2(-44, -46 + _b), Vector2(44, -46 + _b)])
		var n := 12
		for i in n + 1:
			var f := float(i) / n
			var x := lerpf(56.0, -56.0, f) + sin(_t * 2.4 + f * 5.0) * 2.0
			var tear := 9.0 if i % 2 == 1 else 0.0
			pts.append(Vector2(x, 58.0 + tear + sin(_t * 3.0 + f * 7.0) * 3.0))
		draw_colored_polygon(pts, CAPE_DARK)
		# Plis plus clairs.
		for k: float in [-34.0, -12.0, 12.0, 34.0]:
			var sway := sin(_t * 2.4 + k * 0.1) * 2.0
			draw_line(Vector2(k * 0.8, -40 + _b), Vector2(k * 1.25 + sway, 56), CAPE, 4.0)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, OUTLINE, 2.0)

	func _draw_legs() -> void:
		for side: float in [-1.0, 1.0]:
			var x := -26.0 if side < 0.0 else 8.0
			draw_rect(Rect2(x + 4, 22, 10, 34), UNDER)           # sous-combinaison
			_plate(x, 22, 18, 16, SUIT, false)                   # cuissard
			_plate(x + 2, 44, 14, 10, SUIT, false)               # jambière
			_plate(x - 2, 37, 22, 8, SUIT_HI, false)             # genouillère
			_rivet(x + 2, 41, false)
			_rivet(x + 16, 41, false)
			_plate(x - 2, 54, 22, 9, SUIT_HI, false)             # botte
			draw_rect(Rect2(x - 2 + (16.0 if side > 0.0 else 0.0), 60, 6, 3), METAL)
			_conduit(Rect2(x + 8, 24, 2, 12), 60.0, false)
			_conduit(Rect2(x + 8, 46, 2, 7), 80.0, false)

	func _draw_arm(side: float) -> void:
		var x := -50.0 if side < 0.0 else 36.0
		draw_rect(Rect2(x + 3, -36 + _b, 8, 50), UNDER)
		_plate(x, -38, 14, 26, SUIT)                             # bras
		# Coude : rotule et piston hydraulique.
		draw_circle(Vector2(x + 7, -10 + _b), 6.0, OUTLINE)
		draw_circle(Vector2(x + 7, -10 + _b), 4.0, METAL.darkened(0.3))
		var px := x - 3.0 if side < 0.0 else x + 17.0
		draw_line(Vector2(px, -32 + _b), Vector2(px, -4 + _b), OUTLINE, 4.0)
		draw_line(Vector2(px, -32 + _b), Vector2(px, -18 + _b), METAL, 2.0)
		draw_line(Vector2(px, -18 + _b), Vector2(px, -4 + _b), TRIM, 2.0)
		# Gantelet : plus large que le bras, jointures au poing.
		_plate(x - 2, -6, 18, 20, SUIT_HI)
		_conduit(Rect2(x + 3, -2, 8, 2), 70.0)
		for k in 3:
			draw_rect(Rect2(x + k * 5, 14 + _b, 4, 4), METAL.darkened(0.2))
		# Émetteur de la lame, au poignet droit (`WRIST`).
		if side > 0.0:
			var e := Vector2(WRIST.x, WRIST.y + _b)
			draw_rect(Rect2(e.x - 4, e.y - 3, 8, 4), OUTLINE)
			draw_rect(Rect2(e.x - 3, e.y - 2, 6, 2),
				TRIM.lerp(_glow, 0.5 + 0.5 * sin(_t * 6.0)))

	func _draw_torso() -> void:
		_plate(-36, -46, 72, 60, SUIT)
		# Plastron : deux pectoraux.
		_plate(-32, -44, 26, 14, SUIT_HI)
		_plate(6, -44, 26, 14, SUIT_HI)
		_rivet(-29, -41)
		_rivet(28, -41)
		# Abdominaux segmentés sous le symbole.
		for row in 2:
			for col in 2:
				_plate(-22 + col * 24, 2 + row * 6, 20, 4, SUIT)
		# Flancs : grilles d'aération.
		for k in 4:
			draw_rect(Rect2(-34, -24 + k * 5 + _b, 6, 2), UNDER)
			draw_rect(Rect2(28, -24 + k * 5 + _b, 6, 2), UNDER)
		# Circuit : du symbole vers les épaules et les hanches.
		_conduit(Rect2(-30, -38, 2, 44), 30.0)
		_conduit(Rect2(28, -38, 2, 44), 30.0)
		_conduit(Rect2(-30, -38, 16, 2), 20.0)
		_conduit(Rect2(14, -38, 16, 2), 20.0)
		_conduit(Rect2(-14, -14, 2, 18), 10.0)
		_conduit(Rect2(12, -14, 2, 18), 10.0)
		# Ceinture, boucle hexagonale, sacoches.
		_plate(-38, 14, 76, 8, SUIT_HI, false)
		var bk := Vector2(0, 18)
		var hex_out := PackedVector2Array()
		var hex_in := PackedVector2Array()
		for i in 6:
			var d := Vector2.RIGHT.rotated(TAU * i / 6.0)
			hex_out.append(bk + d * 6.0)
			hex_in.append(bk + d * 4.0)
		draw_colored_polygon(hex_out, OUTLINE)
		draw_colored_polygon(hex_in, TRIM.lerp(_glow, 0.4 + 0.3 * sin(_t * 3.0)))
		_plate(-32, 16, 8, 8, SUIT, false)
		_plate(24, 16, 8, 8, SUIT, false)

	func _draw_shoulders() -> void:
		for s in 2:
			var side := -1.0 if s == 0 else 1.0
			var x := -58.0 if s == 0 else 30.0
			_plate(x + 2, -36, 24, 7, SUIT)                    # lame inférieure
			_plate(x, -52, 28, 17, SUIT_HI)                    # épaulière
			_conduit(Rect2(x + 2, -50, 24, 2), 40.0)
			_rivet(x + 3 if s == 0 else x + 24, -38)
			# Lance-missiles : trois tubes cerclés autour de `SHOULDERS`,
			# bouches noires, qui flambent au tir.
			var pod_c: Color = METAL.lerp(_glow, clampf(_pods_glow * 2.0, 0.0, 1.0))
			var cx := SHOULDERS[s].x
			for k in 3:
				var tx := cx - 8.0 + k * 6.0
				draw_rect(Rect2(tx - 1, -46 + _b, 6, 6), OUTLINE)
				draw_rect(Rect2(tx, -45 + _b, 4, 4), pod_c)
				draw_rect(Rect2(tx + 1, -44 + _b, 2, 2), UNDER)
			# Vapeur des évents dès la phase 2.
			if phase >= 1:
				for i in 3:
					var f := fmod(_t * 0.9 + i * 0.33, 1.0)
					var at := Vector2(cx + side * (6.0 + f * 10.0), -54.0 + _b - f * 26.0)
					draw_circle(at, 3.0 + f * 5.0, Color(0.7, 0.72, 0.78, 0.28 * (1.0 - f)))

	func _draw_head() -> void:
		_plate(-10, -54, 20, 10, SUIT)                        # cou
		for k in 3:
			draw_rect(Rect2(-7, -52 + k * 3 + _b, 14, 1), UNDER)
		_plate(-20, -82, 40, 30, SUIT)                        # casque
		_plate(-24, -66, 8, 16, SUIT_HI)                      # garde-joues
		_plate(16, -66, 8, 16, SUIT_HI)
		_plate(-4, -92, 8, 14, SUIT_HI)                       # crête
		_conduit(Rect2(-1, -90, 2, 10), 50.0)
		# Antennes, pointe qui clignote.
		var blink := Color(1.0, 0.25, 0.2) if fmod(_t, 1.2) < 0.2 else Color(0.35, 0.08, 0.08)
		for side: float in [-1.0, 1.0]:
			var base := Vector2(side * 16.0, -80.0 + _b)
			var tip := base + Vector2(side * 9.0, -14.0)
			draw_line(base, tip, OUTLINE, 3.0)
			draw_line(base, tip, METAL, 1.0)
			draw_rect(Rect2(tip - Vector2(1.5, 1.5), Vector2(3, 3)), blink)
		# Grille de la bouche.
		for k in 4:
			draw_rect(Rect2(-9 + k * 5, -57 + _b, 3, 2), UNDER)
		# Visière jaune : une fente large, plus vive pendant la charge, qu'un
		# balayage de lecture parcourt.
		var vg := clampf(_visor_glow, 0.0, 1.0)
		var visor_c: Color = _glow.lerp(Color.WHITE, vg * 0.6)
		var vy := VISOR.y + _b
		if vg > 0.0:
			draw_rect(Rect2(-22, vy - 7, 44, 14), Color(visor_c, 0.35 * vg))
		draw_rect(Rect2(-18, vy - 6, 36, 12), OUTLINE)
		draw_rect(Rect2(-16, vy - 4, 32, 8), visor_c)
		draw_rect(Rect2(-16, vy + 2, 32, 2), visor_c.darkened(0.35))
		draw_rect(Rect2(-14, vy - 3, 12, 2), Color(1, 1, 1, 0.75))
		var scan := -16.0 + fmod(_t * 40.0, 30.0)
		draw_rect(Rect2(scan, vy - 4, 2, 8), Color(1, 1, 1, 0.55))

	## Symbole du torse : losange dans une monture rivetée, triangle évidé.
	func _draw_core() -> void:
		var cg := clampf(_core_glow, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_t * (3.0 + phase))
		var core_c: Color = _glow.lerp(Color.WHITE, cg * 0.6)
		var c := Vector2(0, CORE.y + _b)
		draw_circle(c, 15.0 + 3.0 * cg, Color(core_c, 0.18 + 0.15 * pulse + 0.3 * cg))
		draw_arc(c, 15.0, 0.0, TAU, 24, OUTLINE, 3.0)
		draw_arc(c, 15.0, 0.0, TAU, 24, METAL.darkened(0.4), 1.0)
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			_rivet(c.x + cos(a) * 15.0, c.y + sin(a) * 15.0, false)
		var diamond := PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0),
			c + Vector2(0, 12), c + Vector2(-12, 0)])
		draw_colored_polygon(diamond, core_c)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0),
			c]), core_c.lightened(0.3))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 4),
			c + Vector2(-5, 4)]), SUIT)
		var rim := diamond.duplicate()
		rim.append(diamond[0])
		draw_polyline(rim, OUTLINE, 2.0)

	## Usure de combat : fissures lumineuses cumulées, étincelles dès la phase 3.
	func _draw_damage() -> void:
		var crack_c := Color(_glow, 0.6 + 0.3 * sin(_t * 7.0))
		for p in mini(phase, CRACKS.size() - 1) + 1:
			for crack: Array in CRACKS[p]:
				var dy := _b if crack[0] else 0.0
				var pts := PackedVector2Array()
				for k in range(1, crack.size()):
					pts.append(crack[k] + Vector2(0, dy))
				draw_polyline(pts, OUTLINE, 3.0)
				draw_polyline(pts, crack_c, 1.0)
		if phase >= 2:
			for i in SPARK_SPOTS.size():
				var f := fmod(_t * 3.0 + i * 0.37, 1.0)
				if f < 0.35:
					var at := SPARK_SPOTS[i] + Vector2(0, _b) \
						+ Vector2((i % 3 - 1) * 6.0, -4.0) * f * 3.0
					draw_rect(Rect2(at, Vector2(2, 2)), Color(1.0, 0.9, 0.5, 1.0 - f * 2.0))
