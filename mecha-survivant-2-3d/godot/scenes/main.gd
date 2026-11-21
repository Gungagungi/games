extends Node3D
## Point d'entrée : monde, mech, caméra, vagues, interface, et l'enchaînement
## titre → vague → choix d'un pouvoir → vague suivante → fin (v2 : `main.gd`).
##
## Tout est construit en code ; `main.tscn` ne contient que ce nœud.
##
## Modes de lancement :
##   -- --smoke [--wave=N] [--waves=K]   partie accélérée sans écran, mech
##        immortel en pilote automatique, pouvoirs choisis seuls ; part de la
##        vague N (1 par défaut, avec les pouvoirs qu'on aurait eus) et
##        s'arrête après K vagues conclues (4 par défaut) ou à la victoire.
##        Sort en code 1 si le temps de jeu alloué est dépassé.
##        Avec --mortal, le mech n'est plus immortel : la partie se termine
##        aussi (en succès) quand il tombe — c'est ce qui exerce les dégâts,
##        l'embrasement et la mort, que le smoke ordinaire ne voit jamais.
##   index.html?demo           même pilote automatique, à l'écran (captures).
##   index.html?vague=N        commence à la vague N (web, pour les captures).
##   index.html?galerie        les six ennemis alignés devant le mech, figés :
##                             pour juger les silhouettes sur une capture.

enum State { TITLE, PLAYING, UPGRADE, PAUSED, OVER }

const MOUSE_SENS := 0.0025
const TOUCH_SENS := 0.006
const TOUCH_BUTTON_R := 46.0
const SMOKE_TIME_SCALE := 6.0
## Temps de jeu (pas d'horloge murale) accordé au smoke par vague à conclure.
const SMOKE_SECONDS_PER_WAVE := 150.0

var state := State.TITLE
var mech: Mech
var camera: CameraRig
var village: Village
var waves: WaveManager
var hud: Hud
var upgrade_screen: UpgradeScreen

var kills := 0
var hurt_vignette := 0.0

# Tactile : gauche = stick de marche, droite = caméra, tir automatique.
var touch_stick_active := false
var touch_stick_origin := Vector2.ZERO
var touch_stick_vec := Vector2.ZERO
var _stick_index := -1
var _look_index := -1
var _look_last := Vector2.ZERO

var _firing := false
var _capture_grace := 0.0
var _start_wave := 1
var _gallery := false
var _overlay: Control
var _title: Label
var _subtitle: Label
var _body: Label
var _banner: Label
var _banner_t := 0.0
var _time := 0.0

var _smoke_waves := 4
var _smoke_mortal := false
var _smoke_cleared := 0
var _smoke_budget := 0.0

func _ready() -> void:
	randomize()
	_read_launch_options()
	_setup_input()
	_build_environment()
	village = Village.new()
	add_child(village)
	village.generate()
	mech = Mech.new()
	add_child(mech)
	mech.position = village.start_position()
	camera = CameraRig.new()
	camera.target = mech
	add_child(camera)
	camera.make_current()
	waves = WaveManager.new()
	waves.world = self
	waves.mech = mech
	waves.camera = camera
	add_child(waves)
	_build_ui()
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_hurt.connect(func() -> void: hurt_vignette = 1.0)
	EventBus.screen_shake_requested.connect(func(a: float) -> void: camera.shake = maxf(camera.shake, a))
	EventBus.float_text_requested.connect(_on_float_text)
	upgrade_screen.upgrade_chosen.connect(_on_upgrade_chosen)
	camera.follow(0.0)
	if _gallery:
		_show_gallery()
	elif GameState.autopilot:
		_start_game()
	else:
		AudioManager.play_music("menu")
		_show_title()

func _read_launch_options() -> void:
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args:
		GameState.smoke_test = true
		GameState.autopilot = true
		Engine.time_scale = SMOKE_TIME_SCALE
		for a in args:
			if a.begins_with("--wave="):
				_start_wave = clampi(int(a.trim_prefix("--wave=")), 1, GameState.FINAL_WAVE)
			elif a.begins_with("--waves="):
				_smoke_waves = maxi(1, int(a.trim_prefix("--waves=")))
		_smoke_mortal = "--mortal" in args
		_smoke_budget = SMOKE_SECONDS_PER_WAVE * _smoke_waves
		print("[smoke] départ vague %d, %d vague(s) à conclure" % [_start_wave, _smoke_waves])
	if OS.has_feature("web"):
		var search = JavaScriptBridge.eval("window.location.search", true)
		if typeof(search) == TYPE_STRING:
			GameState.autopilot = GameState.autopilot or "demo" in search
			_gallery = "galerie" in search
			var m := RegEx.create_from_string("vague=(\\d+)").search(search)
			if m != null:
				_start_wave = clampi(int(m.get_string(1)), 1, GameState.FINAL_WAVE)

# --- Entrées -------------------------------------------------------------

func _setup_input() -> void:
	# Touches physiques : ZQSD sur AZERTY et WASD sur QWERTY sont les mêmes.
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"dash": [KEY_SHIFT, KEY_SPACE],
		"shockwave": [KEY_F, KEY_E],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.autopilot:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input(event)
		return
	# Godot émule une souris à partir des doigts (c'est ce qui fait marcher
	# les boutons de l'écran de pouvoirs) : en jeu, ces clics émulés ne
	# doivent ni tirer ni tourner la caméra.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventKey and event.pressed:
		GameState.touch_mode = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			match state:
				State.TITLE, State.OVER, State.PAUSED:
					_resume_or_start()
					return
			if state == State.PLAYING and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_capture_mouse()
				return
		_firing = event.pressed and state == State.PLAYING
	elif event is InputEventMouseMotion and state == State.PLAYING \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.add_look(event.relative.x * MOUSE_SENS, event.relative.y * MOUSE_SENS)
	elif state == State.PLAYING and event.is_action_pressed("dash"):
		mech.try_dash()
	elif state == State.PLAYING and event.is_action_pressed("shockwave"):
		_shockwave()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause()

func _touch_input(event: InputEvent) -> void:
	GameState.touch_mode = true
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if state == State.UPGRADE:
				return  # les cartes se touchent par l'émulation souris
			if state != State.PLAYING:
				_resume_or_start()
				return
			if event.position.distance_to(dash_button_center()) < TOUCH_BUTTON_R * 1.3:
				mech.try_dash()
			elif mech.aoe_unlocked and event.position.distance_to(wave_button_center()) < TOUCH_BUTTON_R * 1.3:
				_shockwave()
			elif event.position.x < vp.x * 0.4 and _stick_index < 0:
				_stick_index = event.index
				touch_stick_origin = event.position
				touch_stick_vec = Vector2.ZERO
				touch_stick_active = true
			elif _look_index < 0:
				_look_index = event.index
				_look_last = event.position
		else:
			if event.index == _stick_index:
				_release_stick()
			elif event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			touch_stick_vec = ((event.position - touch_stick_origin) / 70.0).limit_length(1.0)
		elif event.index == _look_index:
			# Pas event.relative : sur le web, Godot 4.7 le calcule par rapport
			# au dernier doigt qui a bougé, pas à ce doigt-ci (prototype).
			var rel: Vector2 = event.position - _look_last
			_look_last = event.position
			camera.add_look(rel.x * TOUCH_SENS, rel.y * TOUCH_SENS)

func _release_stick() -> void:
	_stick_index = -1
	touch_stick_active = false
	touch_stick_vec = Vector2.ZERO

func dash_button_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - 90, vp.y - 110)

func wave_button_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - 200, vp.y - 80)

func _capture_mouse() -> void:
	if GameState.touch_mode or GameState.autopilot:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Le verrouillage du pointeur est asynchrone dans un navigateur : on ne
	# conclut pas tout de suite qu'il a échoué.
	_capture_grace = 1.0

func _read_move() -> Vector3:
	var v := Vector2.ZERO
	if GameState.touch_mode:
		v = Vector2(touch_stick_vec.x, -touch_stick_vec.y)
	else:
		v.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		v.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		v = v.limit_length(1.0)
	return camera.right_flat() * v.x + camera.forward_flat() * v.y

# --- Boucle ----------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta, 0.1 * Engine.time_scale)
	hurt_vignette = maxf(hurt_vignette - delta * 2.0, 0.0)
	_banner_t = maxf(_banner_t - delta, 0.0)
	_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	if state == State.TITLE:
		camera.yaw += delta * 0.12   # lent tour d'horizon autour du mech
	if state != State.PLAYING:
		camera.follow(delta)
		return
	_time += delta
	_capture_grace = maxf(_capture_grace - delta, 0.0)
	if not GameState.touch_mode and not GameState.autopilot and _capture_grace <= 0.0 \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_pause()   # Échap a rendu le pointeur au navigateur
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var auto_target: Enemy = null
	if GameState.autopilot:
		auto_target = _autopilot(delta, enemies)
	else:
		mech.move_dir = _read_move()
	mech.aim_yaw = camera.yaw
	var motion := mech.step(delta)
	var moved := village.move_circle(Vector2(mech.position.x, mech.position.z),
		Vector2(motion.x, motion.z), Mech.RADIUS)
	mech.position = Vector3(moved.x, 0.0, moved.y)

	camera.follow(delta)
	camera.update_aim(enemies)
	var want_fire := _firing
	var aim := camera.aim_point
	if GameState.autopilot:
		want_fire = auto_target != null
		if auto_target != null:
			aim = auto_target.aim_point()
	elif GameState.touch_mode:
		var assisted := _touch_aim_assist(enemies)
		want_fire = assisted != null
		if assisted != null and camera.aim_enemy == null:
			aim = assisted.aim_point()
	if want_fire:
		for shot in mech.fire(aim, delta):
			var b := Bullet.new()
			b.setup(shot[0], shot[1], mech.bullet_damage)
			add_child(b)
	_separate(enemies)
	if GameState.smoke_test:
		_smoke_tick(delta, enemies)

## Au doigt, viser juste est difficile : un ennemi visible à moins de 12° du
## réticule suffit à déclencher le tir, droit sur lui (prototype).
func _touch_aim_assist(enemies: Array) -> Enemy:
	if camera.aim_enemy != null:
		return camera.aim_enemy
	var fwd := camera.forward_flat()
	var best_cos := cos(deg_to_rad(12.0))
	var target: Enemy = null
	for node in enemies:
		var e := node as Enemy
		if e == null or e.is_damage_immune():
			continue
		var v: Vector3 = e.position - mech.position
		v.y = 0
		var dist := v.length()
		if dist > 45.0 or dist < 0.1:
			continue
		var cs := v.dot(fwd) / dist
		if cs > best_cos and village.segment_hit(mech.center() + Vector3(0, 0.6, 0), e.aim_point()) == null:
			best_cos = cs
			target = e
	return target

## Séparation entre ennemis : sans elle, la horde se fond en un seul point.
## La poussée est appliquée par chaque ennemi, à travers `move_circle`, pour
## ne jamais pousser quelqu'un dans un mur.
func _separate(enemies: Array) -> void:
	var n := enemies.size()
	for e in enemies:
		(e as Enemy).push = Vector3.ZERO
	for i in n:
		var a := enemies[i] as Enemy
		for j in range(i + 1, n):
			var b := enemies[j] as Enemy
			var v := a.position - b.position
			v.y = 0
			var min_d: float = (a.radius + b.radius) * 0.9
			var d2 := v.length_squared()
			if d2 < min_d * min_d and d2 > 0.0001:
				var d := sqrt(d2)
				var f := v / d * (min_d - d) * 6.0
				a.push += f
				b.push -= f

func _shockwave() -> void:
	if not mech.try_shockwave():
		return
	var fx := ShockwaveRing.new()
	fx.max_radius = Mech.AOE_RADIUS
	fx.position = mech.position
	add_child(fx)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.is_damage_immune():
			continue
		if e.flat().distance_to(Vector2(mech.position.x, mech.position.z)) <= Mech.AOE_RADIUS + e.radius:
			e.take_damage(Mech.AOE_DAMAGE, e.aim_point())

# --- Pilote automatique (smoke et ?demo) -------------------------------------

## Vise l'ennemi visible le plus proche et s'en tient à distance ; sans cible
## visible, va chercher le plus proche par les rues (second champ de
## distances du village). Renvoie la cible sur laquelle tirer, ou null.
func _autopilot(delta: float, enemies: Array) -> Enemy:
	var me := Vector2(mech.position.x, mech.position.z)
	var eye := mech.center() + Vector3(0, 0.6, 0)
	var target: Enemy = null
	var td := INF
	var nearest: Enemy = null
	var nd := INF
	var close := 0
	for node in enemies:
		var e := node as Enemy
		if e == null or not e.alive:
			continue
		var d := e.flat().distance_to(me)
		if d < Mech.AOE_RADIUS:
			close += 1
		if d < nd:
			nd = d
			nearest = e
		if d < td and d < 50.0 and not e.is_damage_immune() \
				and village.segment_hit(eye, e.aim_point(), 0.4) == null:
			td = d
			target = e
	if target != null:
		var c: Vector3 = target.aim_point() - camera.global_position
		var flat := Vector2(c.x, c.z).length()
		var k := minf(1.0, delta * 25.0)
		camera.yaw = lerp_angle(camera.yaw, atan2(-c.x, -c.z), k)
		camera.pitch = lerpf(camera.pitch, clampf(atan2(c.y, flat), CameraRig.PITCH_MIN, CameraRig.PITCH_MAX), k)
	var move := Vector2.ZERO
	if target != null:
		var away := (me - target.flat()).normalized()
		var tangent := Vector2(-away.y, away.x) * (1.0 if int(_time / 4.0) % 2 == 0 else -1.0)
		if td < 6.0:
			move = away * 1.2 + tangent * 0.5
		elif td < 14.0:
			move = tangent
		else:
			move = -away * 0.6 + tangent * 0.4
	elif nearest != null:
		move = village.seek_dir(me, nearest.flat())
	mech.move_dir = Vector3(move.x, 0, move.y).limit_length(1.0) * 0.85
	if close >= 3 and mech.aoe_unlocked:
		_shockwave()
	if nd < 3.0 and mech.can_dash():
		mech.try_dash()
	if GameState.smoke_test and not _smoke_mortal:
		mech.hp = mech.max_hp
	return target

func _smoke_tick(delta: float, enemies: Array) -> void:
	if int(_time / 10.0) != int((_time - delta) / 10.0):
		print("[smoke] t=%.0f s  vague %d  vivants %d  à venir %d  détruits %d  pouvoirs %d" % [
			_time, GameState.wave, enemies.size(), waves.remaining_to_spawn, kills,
			UpgradeManager.owned.size()])
	if _time > _smoke_budget:
		print("[smoke] ÉCHEC : %.0f s de jeu sans conclure %d vague(s) (vague %d, %d ennemis restants)" % [
			_time, _smoke_waves, GameState.wave, waves.remaining()])
		get_tree().quit(1)

# --- Vagues et états ---------------------------------------------------------

func in_play() -> bool:
	return state == State.PLAYING or state == State.PAUSED or state == State.UPGRADE

func _start_game() -> void:
	_clear_transients()
	village.generate()
	mech.reset_stats()
	mech.immortal = GameState.autopilot and not _smoke_mortal
	mech.position = village.start_position()
	UpgradeManager.reset()
	# Commencer plus loin qu'à la vague 1 accorde les pouvoirs qu'on aurait eus.
	for i in _start_wave - 1:
		var choices := UpgradeManager.draw_choices(mech, 1)
		if not choices.is_empty():
			UpgradeManager.apply(choices[0]["id"], mech)
	camera.pitch = -0.2
	camera.current_dist = CameraRig.DIST
	kills = 0
	_time = 0.0
	_smoke_cleared = 0
	_firing = false
	_release_stick()
	state = State.PLAYING
	GameState.running = true
	_overlay.visible = false
	_capture_mouse()
	waves.start_wave(_start_wave)
	_show_banner("VAGUE %d" % _start_wave, 2.0)

## Vide le monde de tout ce qui n'est ni le village, ni le mech, ni les
## systèmes : ennemis, projectiles, effets.
func _clear_transients() -> void:
	for child in get_children():
		if child is Enemy or child is Bullet or child is EnemyProjectile or child is ShockwaveRing \
				or child is FloatText or child is CPUParticles3D:
			child.queue_free()
	waves.stop()

func _on_wave_cleared(n: int) -> void:
	_show_banner("VAGUE %d TERMINÉE" % n, 2.0)
	if GameState.smoke_test:
		_smoke_cleared += 1
		print("[smoke] vague %d conclue (%.0f s de jeu, %d détruits)" % [n, _time, kills])
	if n >= GameState.FINAL_WAVE:
		_victory()
		return
	if GameState.smoke_test and _smoke_cleared >= _smoke_waves:
		print("[smoke] OK : %d vague(s) conclue(s), %d détruits, %.0f s de jeu" % [_smoke_cleared, kills, _time])
		get_tree().quit()
		return
	if GameState.autopilot:
		var choices := UpgradeManager.draw_choices(mech)
		_on_upgrade_chosen(choices[0]["id"])
		return
	state = State.UPGRADE
	GameState.running = false
	_firing = false
	_release_stick()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	upgrade_screen.present(UpgradeManager.draw_choices(mech))

func _on_upgrade_chosen(id: String) -> void:
	UpgradeManager.apply(id, mech)
	if GameState.smoke_test:
		print("[smoke] pouvoir : %s" % id)
	state = State.PLAYING
	GameState.running = true
	_capture_mouse()
	var next := GameState.wave + 1
	waves.start_wave(next)
	_show_banner("VAGUE %d" % next, 2.0)

func _victory() -> void:
	state = State.OVER
	GameState.running = false
	_firing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_music()
	AudioManager.sfx("boss_death")
	if GameState.smoke_test:
		print("[smoke] OK : vague %d conclue — partie gagnée, %d détruits, %.0f s de jeu" % [
			GameState.wave, kills, _time])
		get_tree().quit()
		return
	_title.text = "LES %d VAGUES SONT TOMBÉES" % GameState.FINAL_WAVE
	_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	_subtitle.text = "%d ennemis détruits" % kills
	_body.text = "Les boss arrivent bientôt dans cette version 3D.\n\nCliquer ou toucher pour revenir au titre"
	_overlay.visible = true

func _on_player_died() -> void:
	if GameState.smoke_test:
		print("[smoke] OK : mech détruit à la vague %d, %d détruits, %.0f s de jeu" % [
			GameState.wave, kills, _time])
		get_tree().quit()
	state = State.OVER
	GameState.running = false
	_firing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_music()
	Shapes.burst(self, mech.position + Vector3(0, 2, 0), Color(1, 0.5, 0.1), 40, 12.0, 0.35, true)
	mech.visible = false
	_title.text = "MECH DÉTRUIT"
	_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	_subtitle.text = "Vague %d  ·  %d ennemis détruits" % [GameState.wave, kills]
	_body.text = "Cliquer ou toucher pour revenir au titre"
	_overlay.visible = true

func _on_enemy_died(at: Vector3, col: Color, size: float) -> void:
	kills += 1
	Shapes.burst(self, at, col, 22, 9.0, 0.22 * (size / 2.0))

func _on_float_text(at: Vector3, text: String, col: Color) -> void:
	if GameState.smoke_test:
		return
	var ft := FloatText.new(text, col)
	ft.position = at + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	add_child(ft)

func _resume_or_start() -> void:
	match state:
		State.TITLE:
			_start_game()
		State.OVER:
			_back_to_title()
		State.PAUSED:
			state = State.PLAYING
			GameState.running = true
			_overlay.visible = false
			_capture_mouse()

func _back_to_title() -> void:
	_clear_transients()
	village.generate()
	mech.reset_stats()
	mech.position = village.start_position()
	UpgradeManager.reset()
	GameState.wave = 0
	state = State.TITLE
	AudioManager.play_music("menu")
	_show_title()

func _pause() -> void:
	state = State.PAUSED
	GameState.running = false
	_firing = false
	_release_stick()
	_title.text = "PAUSE"
	_title.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	_subtitle.text = "Cliquer pour reprendre"
	_body.text = ""
	_overlay.visible = true

## Outil de capture : un exemplaire de chaque ennemi, au tier de la vague
## demandée, en arc de cercle devant le mech. Rien ne bouge (`running` faux).
func _show_gallery() -> void:
	_overlay.visible = false
	state = State.PAUSED
	GameState.wave = _start_wave
	camera.yaw = 0.0
	camera.pitch = -0.1
	camera.fov = 48.0
	mech.visible = false
	var types := WaveManager.SCRIPTS.keys()
	for i in types.size():
		var e: Enemy = WaveManager.SCRIPTS[types[i]].new()
		e.configure(EnemyStats.scaled(types[i], GameState.tier()))
		e.mech = mech
		var ang := lerpf(-0.5, 0.5, float(i) / (types.size() - 1))
		e.position = mech.position + Vector3(sin(ang) * 8.0 + 1.3, 0, -cos(ang) * 8.0 + 2.0)
		e.rotation.y = atan2(e.position.x - mech.position.x, e.position.z - mech.position.z)
		add_child(e)
		if e is Risen:
			e.immune = false
			e._emerging = 0.0
			e._body.position.y = 0.0
	camera.follow(0.0)

# --- Monde -------------------------------------------------------------------

## Nuit sur le village : ciel crépusculaire, lune froide qui porte les ombres,
## brouillard qui avale le lointain. Les lanternes et braseros du village
## (`VillageBuilder`) font le reste.
func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.04, 0.05, 0.12)
	sky_mat.sky_horizon_color = Color(0.32, 0.2, 0.22)
	sky_mat.ground_horizon_color = Color(0.18, 0.13, 0.13)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.04)
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.05
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.13, 0.12, 0.17)
	env.fog_density = 0.016
	env.fog_sky_affect = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(28.0), 0)
	moon.light_color = Color(0.62, 0.7, 1.0)
	moon.light_energy = 0.75
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)

# --- Interface ---------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	layer.add_child(_banner)

	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	_title = _label(box, 64, Color(1, 0.8, 0.4))
	_subtitle = _label(box, 26, Color(1, 1, 1, 0.9))
	_body = _label(box, 18, Color(1, 1, 1, 0.75))

	var version := Label.new()
	version.text = _version_text()
	version.add_theme_font_size_override("font_size", 12)
	version.modulate.a = 0.5
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(8, -20)
	_overlay.add_child(version)

	upgrade_screen = UpgradeScreen.new()
	add_child(upgrade_screen)

func _label(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(900.0, get_viewport().get_visible_rect().size.x - 40.0), 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _show_title() -> void:
	_title.text = "MECHA SURVIVANT 2 · 3D"
	_title.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	_subtitle.text = "Le village en ruine, trente vagues de morts-vivants"
	_body.text = "Cliquer pour jouer\n\n" \
		+ "Souris : viser   ·   Clic gauche : tirer   ·   ZQSD / WASD / flèches : marcher\n" \
		+ "Maj ou Espace : dash   ·   F : onde de choc (une fois débloquée)   ·   Échap : pause\n\n" \
		+ "Sur mobile : glisser à gauche pour marcher, à droite pour viser — le tir est automatique.\n" \
		+ "Le radar, en haut à droite, montre en rouge ce qui arrive dans le dos."
	_overlay.visible = true

func _show_banner(text: String, duration: float) -> void:
	_banner.text = text
	_banner_t = duration

func _version_text() -> String:
	if FileAccess.file_exists("res://version.txt"):
		return FileAccess.get_file_as_string("res://version.txt").strip_edges()
	return "dev"
