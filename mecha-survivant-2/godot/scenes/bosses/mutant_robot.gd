class_name MutantRobot
extends BossBase
## Le Robot géant mutant, boss de la vague 30 — la dernière. C'est un des
## petits robots que le Destructeur d'univers envoie au combat, qui a muté :
## même silhouette (`DestroyerRobot.Body`, agrandi `SCALE` fois), boursouflée
## d'excroissances vertes qui pulsent.
##
## Trois phases :
##   1. trois grosses boules de métal lancées en éventail vers le mech, et un
##      éclair tiré de l'antenne (`lightning_arc.gd`) : s'il touche, il reste
##      accroché et coûte 5 % des PV max par seconde pendant 3 s ;
##   2. les boules partent en double salve, cadences resserrées ;
##   3. l'antenne tire un second éclair juste après le premier, visé là où le
##      mech s'est réfugié.
##
## À sa mort il explose en chaîne et lance « tu auras affaire à mon patron » —
## le Destructeur. La vague (donc la partie) ne se conclut qu'une fois la
## réplique refermée : `boss_defeated` attend `dialogue_finished`, sinon
## l'écran de victoire passerait sous la réplique.

const PHASE_HP: Array[float] = [2400.0, 3000.0, 3600.0]
## Agrandissement du petit robot de `destroyer_robot.gd` (26×31 px).
const SCALE := 4.0
## Points d'ancrage, en coordonnées du boss : pointe de l'antenne et bras
## lanceur de `Body`, multipliés par `SCALE`.
const ANTENNA := Vector2(0.0, -16.0) * SCALE
const ARM := Vector2(17.0, -2.0) * SCALE
const MUTANT := Color(0.45, 0.95, 0.35)

const BALL_INTERVAL := 3.2
const BALL_SPREAD := 0.26
const BALL_SPEED := 210.0
const BALL_RADIUS := 15.0
const LIGHTNING_INTERVAL := 7.0
const LIGHTNING_WINDUP := 0.95

var _ball_cd := 1.5
var _lightning_cd := 3.0
var _body: DestroyerRobot.Body
var _mutation: Mutation

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "mutant_robot"
	display_name = "Robot géant mutant"
	radius = 54.0
	speed *= 0.7
	xp_color = Color(0.45, 0.7, 0.4)
	phase_hp = PHASE_HP.duplicate()
	max_hp = phase_hp[0]
	hp = max_hp

func _shape_kind() -> String:
	return "none" if SpriteOrShape.sheet_texture(_sprite_name()) == null else "square"

func _on_spawn() -> void:
	if SpriteOrShape.sheet_texture(_sprite_name()) == null:
		_body = DestroyerRobot.Body.new()
		_body.scale = Vector2.ONE * SCALE
		_visual.add_child(_body)
		_mutation = Mutation.new()
		_mutation.body = _body
		_visual.add_child(_mutation)
	EventBus.dialogue_requested.emit(display_name,
		"BZZT... Je n'étais qu'un petit robot. Puis j'ai GRANDI.")

func _pace() -> float:
	return 1.0 - 0.12 * phase

func _behaviour(delta: float) -> void:
	_keep_range(delta, 230.0)
	if _mutation != null:
		_mutation.phase = phase
	_ball_cd -= delta
	if _ball_cd <= 0.0:
		_ball_cd = BALL_INTERVAL * _pace()
		_throw_balls()
		if phase >= 1:
			get_tree().create_timer(0.45).timeout.connect(func() -> void:
				if alive and player != null and player.alive:
					_throw_balls())
	_lightning_cd -= delta
	if _lightning_cd <= 0.0:
		_lightning_cd = LIGHTNING_INTERVAL * _pace()
		_lightning()
		if phase >= 2:
			get_tree().create_timer(LIGHTNING_WINDUP + 0.6).timeout.connect(func() -> void:
				if alive and player != null and player.alive:
					_lightning())

func _on_phase_started(new_phase: int) -> void:
	if GameState.smoke_test:
		print("[smoke] %s : phase %d/%d" % [display_name, new_phase + 1, phase_count()])
	EventBus.float_text_requested.emit(global_position + Vector2(0, -90),
		["", "MUTATION", "SURTENSION"][new_phase], MUTANT)

## Trois grosses boules de métal en éventail vers le mech.
func _throw_balls() -> void:
	_play_attack()
	if _body != null:
		_body.wind()
	var from := global_position + ARM
	var base := (player.global_position - from).angle()
	for k in [-1, 0, 1]:
		var ball := EnemyProjectile.new()
		ball.setup(from, Vector2.RIGHT.rotated(base + BALL_SPREAD * k), BALL_SPEED,
			hit_damage() * 0.4, BALL_RADIUS, DestroyerRobot.METAL)
		ball.impact_sfx = "bone_sweep"
		get_parent().add_child(ball)
	AudioManager.sfx("enemy_shoot")

## Éclair de l'antenne, visé là où se tient le mech au départ.
func _lightning() -> void:
	_play_attack()
	if _mutation != null:
		_mutation.charge(LIGHTNING_WINDUP)
	var arc := LightningArc.new()
	arc.source = self
	arc.offset = ANTENNA
	arc.target = player.global_position
	arc.windup = LIGHTNING_WINDUP
	get_parent().add_child(arc)

## Mort en deux temps : explosion et réplique d'abord, `boss_defeated` (qui
## conclut la vague 30, donc la partie) seulement à la fermeture de la
## réplique. En smoke, la réplique se referme dans l'appel même : la connexion
## doit donc précéder l'émission.
func die() -> void:
	if not alive:
		return
	alive = false
	AudioManager.sfx("boss_death")
	EventBus.enemy_died.emit(global_position, true)
	var host := get_parent()
	for n in host.get_children():
		if n is EnemyProjectile or n is LightningArc:
			n.queue_free()
	_explode(host)
	EventBus.dialogue_finished.connect(func() -> void: EventBus.boss_defeated.emit(),
		CONNECT_ONE_SHOT)
	EventBus.dialogue_requested.emit(display_name,
		"BZZ... KRRT... Tu as gagné... pour l'instant. Mais tu auras affaire à mon patron.")
	_play_death_then_free()

## Explosions en chaîne sur la carcasse, puis une grande au centre. Les
## positions sont calculées ici : les closures ne capturent que l'arène et des
## valeurs, le robot étant libéré dans la frame (voir `_telegraph_strike`).
func _explode(host: Node) -> void:
	var center := global_position
	EventBus.screen_shake_requested.emit(24.0)
	AudioManager.sfx("shockwave")
	var tree := get_tree()
	for i in 5:
		var at := center + Vector2(randf_range(-50.0, 50.0), randf_range(-60.0, 40.0))
		tree.create_timer(0.08 * i).timeout.connect(func() -> void:
			Blast.spawn(host, at, 60.0, Color(1.0, 0.6, 0.2)))
	Blast.spawn(host, center, 170.0, MUTANT.lerp(Color(1.0, 0.7, 0.3), 0.6))


## Mutation par-dessus le corps du petit robot (non agrandie, pour garder des
## traits fins) : excroissances vertes qui pulsent sur la caisse, plus
## nombreuses à chaque phase, veines lumineuses, et l'antenne qui crépite
## pendant la charge de l'éclair. Suit le rebond de `Body` (`_t` partagé).
class Mutation extends Node2D:
	## Excroissances : position (repère du petit robot) et taille, par phase.
	const GROWTHS := [
		[[Vector2(-6, -6), 3.0], [Vector2(7, -2), 2.5], [Vector2(-9, 2), 2.0]],
		[[Vector2(2, -8), 2.5], [Vector2(9, -7), 2.0], [Vector2(-3, 3), 2.0]],
		[[Vector2(-10, -9), 3.0], [Vector2(5, 3), 2.5], [Vector2(-12, 8), 2.0]],
	]

	var body: Node2D
	var phase := 0
	var _charge := 0.0
	var _t := 0.0

	func charge(duration: float) -> void:
		_charge = duration

	func _process(delta: float) -> void:
		_t += delta
		_charge = maxf(0.0, _charge - delta)
		queue_redraw()

	func _draw() -> void:
		var bt := _t
		if body != null:
			bt = float(body.get("_t"))
		var bob := roundf(sin(bt * 9.0)) * SCALE
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		# Veines : de l'œil vers les bords de la caisse.
		var vein := Color(MUTANT, 0.45 + 0.3 * pulse)
		for v: Array in [[Vector2(-3, -3), Vector2(-8, 4)], [Vector2(3, -3), Vector2(8, -7)],
				[Vector2(0, -1), Vector2(2, 4)]]:
			draw_line(v[0] * SCALE + Vector2(0, bob), v[1] * SCALE + Vector2(0, bob), vein, 3.0)
		for p in mini(phase, GROWTHS.size() - 1) + 1:
			for g: Array in GROWTHS[p]:
				var at: Vector2 = g[0] * SCALE + Vector2(0, bob)
				var r: float = g[1] * SCALE * (0.9 + 0.12 * pulse)
				draw_circle(at, r + 2.0, Color(0, 0, 0))
				draw_circle(at, r, MUTANT.darkened(0.35))
				draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.45, MUTANT.lightened(0.2))
		# Antenne : lueur bleutée qui grandit pendant la charge.
		if _charge > 0.0:
			var tip := ANTENNA + Vector2(0, bob)
			var f := clampf(_charge, 0.0, 1.0)
			draw_circle(tip, 10.0 + 10.0 * f, Color(LightningArc.BOLT, 0.25 + 0.3 * f))
			draw_circle(tip, 5.0, LightningArc.BOLT_CORE)
