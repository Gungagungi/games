class_name DestroyerThrall
extends BossBase
## L'Esclave du Destructeur d'univers, boss de la vague 25. Un serviteur en
## armure de fer rouillé, collier de servitude au cou et marque du Destructeur
## sur le torse : il en reprend les lasers, **en plus lents** — charges
## longues, cadences lâches — pour qu'on apprenne à les esquiver avant de
## croiser le maître.
##
## Ses attaques :
##   - rayon de visière **explosif** : le rayon vise un point (la position du
##     mech au départ) et s'arrête dessus ; un cercle s'y remplit pendant la
##     charge, et le point explose quand le rayon l'atteint ;
##   - fléau : une boule piquante au bout d'une chaîne, tenue de la main
##     gauche (`HAND`), qui tournoie puis frappe (`chain_flail.gd`) ;
##   - explosion de proximité : trop près de lui, il se met à rougeoyer et
##     explose sur place (zone annoncée autour de lui) ;
##   - phase 2 : éventail de trois rayons lents depuis la marque du torse, et
##     le rayon de visière part en double (point visé, puis point d'arrivée).
##
## Dessiné en code par `Figure` ci-dessous ; une planche `boss_thrall.png`
## déposée prendrait le relais, à condition de placer visière, marque et main
## aux hauteurs de `VISOR`, `CORE` et `HAND`.

const PHASE_HP: Array[float] = [2600.0, 3300.0]

const VISOR := Vector2(0.0, -50.0)
const CORE := Vector2(0.0, -14.0)
const HAND := Vector2(-40.0, 10.0)
const AMBER := Color(1.0, 0.62, 0.15)
const AMBER_CORE := Color(1.0, 0.9, 0.6)
const BLAST_RED := Color(1.0, 0.35, 0.2)

## Charges et cadences : nettement plus lentes que le Destructeur (0,85 s de
## charge pour sa visière, 0,95 s pour son éventail).
const VISOR_INTERVAL := 3.6
const VISOR_WINDUP := 1.35
const VISOR_MAX_RANGE := 560.0
const RAY_BLAST_RADIUS := 72.0
const FAN_INTERVAL := 5.8
const FAN_WINDUP := 1.55
const FLAIL_INTERVAL := 4.2
const FLAIL_REACH := 310.0
## Explosion de proximité : distance qui la déclenche, rayon, annonce.
const NEAR_DIST := 125.0
const NEAR_BLAST_RADIUS := 135.0
const NEAR_BLAST_DELAY := 0.75
const NEAR_BLAST_COOLDOWN := 4.5

var _visor_cd := 1.8
var _fan_cd := 2.5
var _flail_cd := 2.5
var _near_cd := 1.0
var _flail: ChainFlail
var _figure: Figure

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "thrall"
	display_name = "L'Esclave du Destructeur d'univers"
	radius = 46.0
	speed *= 0.8
	xp_color = Color(0.45, 0.3, 0.22)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

func _shape_kind() -> String:
	return "none" if SpriteOrShape.sheet_texture(_sprite_name()) == null else "circle"

func _on_spawn() -> void:
	if SpriteOrShape.sheet_texture(_sprite_name()) == null:
		_figure = Figure.new()
		_visual.add_child(_figure)
	EventBus.dialogue_requested.emit(display_name,
		"Mon maître m'a ordonné de t'arrêter... Je n'ai jamais désobéi.")

func _behaviour(delta: float) -> void:
	_keep_range(delta, 210.0)
	var pace := 1.0 if phase == 0 else 0.85
	var dist := global_position.distance_to(player.global_position)
	if _figure != null:
		_figure.phase = phase
		_figure.ball_out = _flail_out()
	_near_cd -= delta
	if _near_cd <= 0.0 and dist <= NEAR_DIST:
		_near_cd = NEAR_BLAST_COOLDOWN
		_proximity_blast()
	_visor_cd -= delta
	if _visor_cd <= 0.0:
		_visor_cd = VISOR_INTERVAL * pace
		_explosive_ray()
	_flail_cd -= delta
	if _flail_cd <= 0.0 and dist <= FLAIL_REACH + 40.0 and not _flail_out():
		_flail_cd = FLAIL_INTERVAL * pace
		_swing_flail()
	if phase >= 1:
		_fan_cd -= delta
		if _fan_cd <= 0.0:
			_fan_cd = FAN_INTERVAL
			_core_fan()

func _on_phase_started(new_phase: int) -> void:
	if GameState.smoke_test:
		print("[smoke] %s : phase %d/%d" % [display_name, new_phase + 1, phase_count()])
	EventBus.float_text_requested.emit(global_position + Vector2(0, -100),
		"LA MARQUE DU MAÎTRE BRÛLE", AMBER)

func _flail_out() -> bool:
	return _flail != null and is_instance_valid(_flail)

func _laser(origin_offset: Vector2, angle: float, dmg: float, windup: float,
		length: float = LaserBeam.LENGTH, follow: bool = true) -> void:
	var beam := LaserBeam.new()
	beam.source = self
	beam.offset = origin_offset
	beam.angle = angle
	beam.damage = dmg
	beam.windup = windup
	beam.firing = 0.35
	beam.width = 14.0
	beam.length = length
	beam.follow = follow
	beam.color = AMBER
	beam.core_color = AMBER_CORE
	get_parent().add_child(beam)
	if _figure != null:
		_figure.charge(origin_offset == VISOR, windup)

## Rayon de visière qui s'arrête sur un point et le fait exploser. Figé à sa
## naissance (`follow = false`) : son extrémité reste sur le cercle annoncé.
## En phase 2, un second rayon vise peu après là où le mech est allé.
func _explosive_ray() -> void:
	_play_attack()
	_ray_at(player.global_position)
	if phase >= 1:
		get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if alive and player != null and player.alive:
				_ray_at(player.global_position))

func _ray_at(at: Vector2) -> void:
	var from := global_position + VISOR
	var to := at - from
	if to.length() > VISOR_MAX_RANGE:
		to = to.normalized() * VISOR_MAX_RANGE
	_laser(VISOR, to.angle(), hit_damage() * 0.35, VISOR_WINDUP, to.length(), false)
	_telegraph_strike(from + to, RAY_BLAST_RADIUS, hit_damage() * 0.5,
		VISOR_WINDUP, AMBER, 9.0, true)

## Phase 2 : trois rayons lents depuis la marque du torse, bien écartés.
func _core_fan() -> void:
	_play_attack()
	var base := (player.global_position - (global_position + CORE)).angle()
	for k in [-1, 0, 1]:
		_laser(CORE, base + 0.42 * k, hit_damage() * 0.4, FAN_WINDUP)

func _swing_flail() -> void:
	_play_attack()
	_flail = ChainFlail.new()
	_flail.source = self
	_flail.offset = HAND
	_flail.target = player.global_position
	_flail.damage = hit_damage() * 0.6
	_flail.reach = FLAIL_REACH
	get_parent().add_child(_flail)

## Trop près : il rougeoit le temps de l'annonce, puis explose sur place.
func _proximity_blast() -> void:
	if _figure != null:
		_figure.overheat(NEAR_BLAST_DELAY)
	EventBus.float_text_requested.emit(global_position + Vector2(0, -90), "!", BLAST_RED)
	_telegraph_strike(global_position, NEAR_BLAST_RADIUS, hit_damage() * 0.55,
		NEAR_BLAST_DELAY, BLAST_RED, 14.0, true)

func die() -> void:
	if not alive:
		return
	super()
	# Ses rayons et zones en cours ne doivent pas tuer le mech après la victoire.
	for n in get_parent().get_children():
		if n is LaserBeam or n is Telegraph or n is ChainFlail:
			n.queue_free()
	Blast.spawn(get_parent(), global_position, 110.0, AMBER)
	EventBus.dialogue_requested.emit(display_name,
		"Pardon... maître...")


## L'Esclave, dessiné en pixels pleins : plus petit et plus voûté que son
## maître, armure de fer rouillé à plaques rivetées, collier de servitude dont
## pend une chaîne brisée, marque du Destructeur (losange) gravée sur le
## torse, visière ambre. La main gauche tient la chaîne du fléau : la boule
## pend à ses pieds tant qu'elle n'est pas lancée (`ball_out`).
class Figure extends Node2D:
	const IRON := Color(0.27, 0.25, 0.25)
	const IRON_HI := Color(0.4, 0.36, 0.33)
	const RUST := Color(0.48, 0.25, 0.12)
	const UNDER := Color(0.06, 0.05, 0.05)
	const METAL := Color(0.55, 0.56, 0.6)
	const OUTLINE := Color(0.0, 0.0, 0.0)

	var phase := 0
	var ball_out := false
	var _t := 0.0
	var _visor_glow := 0.0
	var _core_glow := 0.0
	var _heat := 0.0
	var _heat_len := 1.0
	var _b := 0.0

	func charge(visor: bool, duration: float) -> void:
		if visor:
			_visor_glow = maxf(_visor_glow, duration + 0.3)
		else:
			_core_glow = maxf(_core_glow, duration + 0.3)

	func overheat(duration: float) -> void:
		_heat = duration
		_heat_len = duration

	func _process(delta: float) -> void:
		_t += delta
		_visor_glow = maxf(0.0, _visor_glow - delta)
		_core_glow = maxf(0.0, _core_glow - delta)
		_heat = maxf(0.0, _heat - delta)
		queue_redraw()

	func _plate(x: float, y: float, w: float, h: float, c: Color, up := true) -> void:
		if up:
			y += _b
		draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), OUTLINE)
		draw_rect(Rect2(x, y, w, h), c)
		draw_rect(Rect2(x, y, w, 2), c.lightened(0.25))
		draw_rect(Rect2(x, y + h - 2, w, 2), c.darkened(0.5))

	func _rivet(x: float, y: float) -> void:
		draw_rect(Rect2(x - 1, y - 1 + _b, 3, 3), UNDER)
		draw_rect(Rect2(x - 1, y - 1 + _b, 2, 2), METAL)

	func _rust(x: float, y: float, w: float, h: float) -> void:
		draw_rect(Rect2(x, y + _b, w, h), Color(RUST, 0.85))

	func _draw() -> void:
		_b = roundf(sin(_t * 1.6) * 1.5)
		# Surchauffe avant l'explosion de proximité : halo rouge qui enfle.
		if _heat > 0.0:
			var f := 1.0 - _heat / _heat_len
			var flick := 0.5 + 0.5 * sin(_t * 40.0)
			draw_circle(Vector2(0, -10), 50.0 + 40.0 * f,
				Color(BLAST_RED, 0.15 + 0.25 * f * flick))
		draw_set_transform(Vector2(0, 56), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
		_draw_legs()
		_draw_arms()
		_draw_torso()
		_draw_head()
		_draw_mark()
		if not ball_out:
			_draw_hanging_ball()
		if _heat > 0.0:
			# Tout le corps vire au rouge pendant l'annonce.
			var f := 1.0 - _heat / _heat_len
			draw_rect(Rect2(-40, -70 + _b, 80, 128), Color(BLAST_RED, 0.25 * f))

	func _draw_legs() -> void:
		for x: float in [-24.0, 6.0]:
			draw_rect(Rect2(x + 4, 18, 10, 30), UNDER)
			_plate(x, 18, 18, 14, IRON, false)
			_plate(x - 1, 32, 20, 7, IRON_HI, false)
			_plate(x + 1, 40, 16, 8, IRON, false)
			_plate(x - 3, 48, 23, 8, IRON_HI, false)
		draw_rect(Rect2(-20, 22, 6, 4), RUST)
		draw_rect(Rect2(14, 44, 5, 3), RUST)

	func _draw_arms() -> void:
		# Bras gauche : tendu vers le bas, la main serre la chaîne (`HAND`).
		_plate(-46, -32, 13, 26, IRON)
		_plate(-47, -6, 16, 16, IRON_HI)
		_rust(-44, -26, 5, 4)
		# Bras droit : massif, menotte au poignet.
		_plate(33, -32, 13, 26, IRON)
		_plate(32, -6, 16, 16, IRON_HI)
		draw_rect(Rect2(31, 4 + _b, 18, 4), OUTLINE)
		draw_rect(Rect2(32, 5 + _b, 16, 2), METAL)

	func _draw_torso() -> void:
		# Torse voûté : épaules plus hautes que la tête n'est droite.
		_plate(-32, -40, 64, 54, IRON)
		_plate(-38, -44, 22, 14, IRON_HI)
		_plate(16, -44, 22, 14, IRON_HI)
		_rivet(-34, -40)
		_rivet(33, -40)
		_rivet(-26, 6)
		_rivet(25, 6)
		_rust(-28, -24, 7, 5)
		_rust(18, -2, 9, 4)
		_rust(-10, 4, 4, 6)
		_plate(-34, 12, 68, 7, IRON_HI, false)
		# Collier de servitude et chaîne brisée qui pend sur le torse.
		draw_rect(Rect2(-14, -46 + _b, 28, 7), OUTLINE)
		draw_rect(Rect2(-12, -45 + _b, 24, 5), METAL.darkened(0.2))
		draw_rect(Rect2(-2, -44 + _b, 4, 3), AMBER.darkened(0.3))
		for i in 3:
			var at := Vector2(6 + i * 2, -38 + i * 6 + _b)
			draw_rect(Rect2(at, Vector2(4, 5)), OUTLINE)
			draw_rect(Rect2(at + Vector2(1, 1), Vector2(2, 3)), METAL)

	func _draw_head() -> void:
		# Tête basse, enfoncée entre les épaules.
		_plate(-16, -64, 32, 22, IRON)
		_plate(-19, -56, 6, 12, IRON_HI)
		_plate(13, -56, 6, 12, IRON_HI)
		var vg := clampf(_visor_glow, 0.0, 1.0)
		var visor_c: Color = AMBER.lerp(Color.WHITE, vg * 0.5)
		var vy := VISOR.y + _b
		if vg > 0.0:
			draw_rect(Rect2(-18, vy - 6, 36, 12), Color(visor_c, 0.35 * vg))
		draw_rect(Rect2(-14, vy - 4, 28, 8), OUTLINE)
		draw_rect(Rect2(-12, vy - 2, 24, 4), visor_c)
		draw_rect(Rect2(-10, vy - 2, 8, 1), Color(1, 1, 1, 0.7))
		# Corne d'antenne cassée, souvenir de celle du maître.
		draw_line(Vector2(10, -64 + _b), Vector2(15, -72 + _b), OUTLINE, 3.0)
		draw_line(Vector2(10, -64 + _b), Vector2(15, -72 + _b), METAL, 1.0)

	## Marque du Destructeur au torse : un losange plus terne que le sien,
	## qui s'avive pendant la charge de l'éventail et brûle en phase 2.
	func _draw_mark() -> void:
		var cg := clampf(_core_glow, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var base := AMBER.darkened(0.45 if phase == 0 else 0.1)
		var c := Vector2(CORE.x, CORE.y + _b)
		var col: Color = base.lerp(Color.WHITE, cg * 0.5)
		if phase >= 1 or cg > 0.0:
			draw_circle(c, 12.0 + 3.0 * cg, Color(col, 0.15 + 0.15 * pulse + 0.3 * cg))
		var diamond := PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0),
			c + Vector2(0, 9), c + Vector2(-9, 0)])
		draw_colored_polygon(diamond, col)
		var rim := diamond.duplicate()
		rim.append(diamond[0])
		draw_polyline(rim, OUTLINE, 2.0)

	## Boule au repos : la chaîne descend de la main jusqu'au sol.
	func _draw_hanging_ball() -> void:
		var hand := Vector2(HAND.x, HAND.y + _b)
		var ball := Vector2(HAND.x - 10.0 + sin(_t * 1.6) * 3.0, 50.0)
		var span := ball - hand
		for i in 4:
			var at := hand + span * (i + 0.5) / 4.0
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), OUTLINE)
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), ChainFlail.STEEL_DARK)
		for i in 8:
			var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
			draw_line(ball + d * 8.0, ball + d * 16.0, OUTLINE, 4.0)
			draw_line(ball + d * 8.0, ball + d * 15.0, ChainFlail.STEEL.lightened(0.2), 2.0)
		draw_circle(ball, 12.0, OUTLINE)
		draw_circle(ball, 10.0, ChainFlail.STEEL)
		draw_circle(ball + Vector2(-3, -3), 4.0, ChainFlail.STEEL.lightened(0.35))
