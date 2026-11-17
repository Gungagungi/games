extends Node3D
# Prototype 3D de Mecha Survivant 2, caméra à la troisième personne.
#
# Tout est construit ici en code : arène, lumières, mech, ennemis, caméra,
# interface. Une seule boucle (_process) : entrées → mech → caméra/visée →
# tirs → ennemis → collisions → vagues. Pas de moteur physique : tout se
# règle par distances et cercles, comme dans la v1.
#
# Modes de lancement :
#   -- --smoke     (ligne de commande, sans écran) partie accélérée, mech
#                  immortel en pilote automatique, s'arrête à la vague 4.
#   index.html?demo (web) même pilote automatique, à l'écran, pour les captures.

const Shapes := preload("res://scenes/shapes.gd")
const MechScript := preload("res://scenes/mech.gd")
const EnemyScript := preload("res://scenes/enemy.gd")
const HudScript := preload("res://scenes/hud.gd")
const GroundShader := preload("res://scenes/ground.gdshader")

enum State { TITLE, PLAYING, PAUSED, OVER }

const ARENA_RADIUS := 46.0
const CAM_DIST := 7.5
const CAM_HEIGHT := 3.4
const CAM_SHOULDER := 1.3
const PITCH_MIN := -0.95
const PITCH_MAX := 0.3
const MOUSE_SENS := 0.0025
const TOUCH_SENS := 0.006
const BULLET_SPEED := 80.0
const BULLET_LIFE := 1.6
const MAX_ALIVE := 60
const SMOKE_LAST_WAVE := 4
const DASH_BUTTON_R := 46.0

var state := State.TITLE
var smoke := false
var autopilot := false

var mech: Node3D
var camera: Camera3D
var hud: Control
var enemies: Array = []
var bullets: Array = []  # {node, pos, dir, life}
var obstacles: Array = []  # {p: Vector2, r: float, h: float}

var cam_yaw := 0.0
var cam_pitch := -0.2
var aim_point := Vector3.ZERO
var aim_on_enemy := false
var hurt_vignette := 0.0
var _shake := 0.0

var wave := 0
var kills := 0
var _to_spawn := 0
var _spawn_cd := 0.0
var _intermission := 0.0
var _firing := false
var _capture_grace := 0.0
var _time := 0.0

# Tactile : moitié gauche = stick de marche, reste = visée, tir automatique.
var touch_mode := false
var touch_stick_active := false
var touch_stick_origin := Vector2.ZERO
var touch_stick_vec := Vector2.ZERO
var _stick_index := -1
var _look_index := -1
var _look_last := Vector2.ZERO

var _overlay: Control
var _title: Label
var _subtitle: Label
var _body: Label
var _banner: Label
var _banner_t := 0.0
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _streams := {}
var _music: AudioStreamPlayer


func _ready() -> void:
	randomize()
	smoke = "--smoke" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var search = JavaScriptBridge.eval("window.location.search", true)
		autopilot = typeof(search) == TYPE_STRING and "demo" in search
	autopilot = autopilot or smoke
	if smoke:
		Engine.time_scale = 4.0
	_setup_input()
	_build_world()
	mech = MechScript.new()
	add_child(mech)
	mech.immortal = autopilot
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.far = 260.0
	add_child(camera)
	_build_ui()
	_setup_audio()
	_update_camera(0.0)
	if autopilot:
		_start_game()
	else:
		_show_overlay()


# --- Entrées -------------------------------------------------------------

func _setup_input() -> void:
	# Touches physiques : ZQSD sur AZERTY et WASD sur QWERTY sont les mêmes.
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"dash": [KEY_SPACE, KEY_SHIFT],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if autopilot:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state != State.PLAYING:
				_resume_or_start()
				return
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_capture_mouse()
				return
		_firing = event.pressed
	elif event is InputEventMouseMotion and state == State.PLAYING and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * MOUSE_SENS
		cam_pitch = clampf(cam_pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	elif event.is_action_pressed("dash") and state == State.PLAYING:
		if mech.try_dash():
			_play("dash", -6.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause()


func _touch_input(event: InputEvent) -> void:
	touch_mode = true
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if state != State.PLAYING:
				_resume_or_start()
				return
			if event.position.distance_to(dash_button_center()) < DASH_BUTTON_R * 1.3:
				if mech.try_dash():
					_play("dash", -6.0)
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
				_stick_index = -1
				touch_stick_active = false
				touch_stick_vec = Vector2.ZERO
			elif event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			touch_stick_vec = ((event.position - touch_stick_origin) / 70.0).limit_length(1.0)
		elif event.index == _look_index:
			# Pas event.relative : sur le web, Godot 4.7 le calcule par rapport
			# au dernier doigt qui a bougé, pas à ce doigt-ci. Dès que le stick
			# de marche bouge aussi, la caméra « sautait » de centaines de
			# pixels. On garde donc nous-mêmes la dernière position du doigt.
			var rel: Vector2 = event.position - _look_last
			_look_last = event.position
			cam_yaw -= rel.x * TOUCH_SENS
			cam_pitch = clampf(cam_pitch - rel.y * TOUCH_SENS, PITCH_MIN, PITCH_MAX)


func dash_button_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - 90, vp.y - 110)


func _capture_mouse() -> void:
	if touch_mode or autopilot:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Le verrouillage du pointeur est asynchrone dans un navigateur : on ne
	# conclut pas tout de suite qu'il a échoué.
	_capture_grace = 1.0


func _read_move() -> Vector3:
	var v := Vector2.ZERO
	if touch_mode:
		v = Vector2(touch_stick_vec.x, -touch_stick_vec.y)
	else:
		v.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		v.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		v = v.limit_length(1.0)
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	return right * v.x + fwd * v.y


# --- Boucle ----------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_time += delta
	hurt_vignette = maxf(hurt_vignette - delta * 2.0, 0.0)
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_banner_t = maxf(_banner_t - delta, 0.0)
	_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	if state != State.PLAYING:
		_update_camera(delta)
		return
	_capture_grace = maxf(_capture_grace - delta, 0.0)
	if not touch_mode and not autopilot and _capture_grace <= 0.0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_pause()  # Échap a rendu le pointeur au navigateur
		return

	if autopilot:
		_autopilot(delta)
	else:
		mech.move_dir = _read_move()
	mech.aim_yaw = cam_yaw
	var motion: Vector3 = mech.step(delta)
	mech.position = _resolve(mech.position + motion, mech.RADIUS)

	_update_camera(delta)
	_update_aim()
	var want_fire := _firing or autopilot
	if touch_mode:
		want_fire = _touch_aim_assist()
	if want_fire:
		var shot: Array = mech.try_fire(aim_point)
		if not shot.is_empty():
			_spawn_bullet(shot[0], shot[1])
			_play("shoot", -16.0, randf_range(0.9, 1.1))

	_update_bullets(delta)
	_update_enemies(delta)
	_update_waves(delta)
	if smoke and int(_time / 10.0) != int((_time - delta) / 10.0):
		print("[smoke] t=%.0f s  vague %d  ennemis %d  à venir %d  détruits %d  balles %d" % [_time, wave, enemies.size(), _to_spawn, kills, bullets.size()])

	if mech.hp <= 0.0:
		_game_over()


func _update_camera(delta: float) -> void:
	var d := Vector3(-sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var pivot: Vector3 = mech.position + Vector3(0, CAM_HEIGHT, 0)
	var pos := pivot - d * CAM_DIST + right * CAM_SHOULDER
	pos.y = maxf(pos.y, 0.6)
	if state == State.TITLE:
		# Écran-titre : lent tour d'horizon autour du mech.
		cam_yaw += delta * 0.15
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	camera.global_position = pos
	camera.look_at(pos + d, Vector3.UP)


# Le réticule est au centre de l'écran : on cherche ce que vise ce rayon
# (ennemi le plus proche, sinon le sol, sinon un point lointain) et les canons
# convergent vers ce point.
func _update_aim() -> void:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var best := 140.0
	aim_on_enemy = false
	for e in enemies:
		var c: Vector3 = e.position + Vector3(0, e.height * 0.55, 0)
		var t := _ray_sphere(origin, dir, c, e.radius * 1.15)
		if t > CAM_DIST + 1.5 and t < best:
			best = t
			aim_on_enemy = true
	if not aim_on_enemy and dir.y < -0.001:
		var tg := -origin.y / dir.y
		if tg > CAM_DIST + 1.5:
			best = minf(best, tg)
	aim_point = origin + dir * best


func _touch_aim_assist() -> bool:
	if aim_on_enemy:
		return true
	# Au doigt, viser juste est difficile : un ennemi à moins de 12° du
	# réticule suffit à déclencher le tir, droit sur lui.
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var best_cos := cos(deg_to_rad(12.0))
	var target = null
	for e in enemies:
		var v: Vector3 = e.position - mech.position
		v.y = 0
		var dist := v.length()
		if dist > 45.0 or dist < 0.1:
			continue
		var cs := v.dot(fwd) / dist
		if cs > best_cos:
			best_cos = cs
			target = e
	if target == null:
		return false
	aim_point = target.position + Vector3(0, target.height * 0.55, 0)
	return true


static func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc := o - c
	var b := oc.dot(d)
	var disc := b * b - (oc.length_squared() - r * r)
	if disc < 0.0:
		return -1.0
	return -b - sqrt(disc)


func _autopilot(delta: float) -> void:
	var nearest = null
	var nd := INF
	for e in enemies:
		var dd: float = e.position.distance_to(mech.position)
		if dd < nd and e._rise >= 1.0:
			nd = dd
			nearest = e
	if nearest != null:
		# Vise depuis la caméra (décalée sur l'épaule), pas depuis le mech.
		var c: Vector3 = nearest.position + Vector3(0, nearest.height * 0.55, 0) - camera.global_position
		var flat := Vector2(c.x, c.z).length()
		# Lissage rapide : un lissage lent laisse la visée en retard d'un
		# mètre sur une cible lointaine pendant que le mech tourne en cercle.
		cam_yaw = lerp_angle(cam_yaw, atan2(-c.x, -c.z), minf(1.0, delta * 25.0))
		cam_pitch = lerpf(cam_pitch, clampf(atan2(c.y, flat), PITCH_MIN, PITCH_MAX), minf(1.0, delta * 25.0))
	# Tourne en cercle autour du centre, recule si un ennemi colle.
	var tangent := Vector3(-mech.position.z, 0, mech.position.x).normalized()
	if mech.position.length() < 6.0:
		tangent = Vector3(cos(_time * 0.3), 0, sin(_time * 0.3))
	var move := tangent + (-mech.position.normalized() * 0.3 if mech.position.length() > 25.0 else Vector3.ZERO)
	if nearest != null and nd < 6.0:
		move += (mech.position - nearest.position).normalized() * 1.5
	mech.move_dir = move.normalized() * 0.8


# --- Tirs ------------------------------------------------------------------

func _spawn_bullet(origin: Vector3, dir: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.14, 1.6)
	node.mesh = mesh
	node.material_override = Shapes.glow_mat(Color(1.0, 0.8, 0.3), 3.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = origin
	node.look_at(origin + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	bullets.append({"node": node, "pos": origin, "dir": dir, "life": BULLET_LIFE})


func _update_bullets(delta: float) -> void:
	var keep: Array = []
	for b in bullets:
		var from: Vector3 = b.pos
		var to: Vector3 = from + b.dir * BULLET_SPEED * delta
		b.life -= delta
		var hit_at = null
		var hit_enemy = null
		for e in enemies:
			var c: Vector3 = e.position + Vector3(0, e.height * 0.55, 0)
			var closest := Geometry3D.get_closest_point_to_segment(c, from, to)
			if closest.distance_to(c) < e.radius * 1.1:
				hit_at = closest
				hit_enemy = e
				break
		if hit_at == null:
			if to.y <= 0.0:
				hit_at = to
			elif Vector2(to.x, to.z).length() > ARENA_RADIUS + 1.0:
				hit_at = to
			else:
				for o in obstacles:
					if to.y < o.h and Vector2(to.x, to.z).distance_to(o.p) < o.r:
						hit_at = to
						break
		if hit_enemy != null:
			_damage_enemy(hit_enemy, mech.BULLET_DAMAGE, hit_at)
		if hit_at != null:
			Shapes.burst(self, hit_at, Color(1.0, 0.75, 0.3), 5, 5.0, 0.1)
			b.node.queue_free()
		elif b.life <= 0.0:
			b.node.queue_free()
		else:
			b.pos = to
			b.node.global_position = to
			keep.append(b)
	bullets = keep


func _damage_enemy(e: Node3D, amount: float, at: Vector3) -> void:
	if e.hit(amount):
		kills += 1
		Shapes.burst(self, at, e.body_color(), 22, 9.0, 0.22 * (e.height / 2.0))
		_play("enemy_death", -6.0, randf_range(0.85, 1.15))
		enemies.erase(e)
		e.queue_free()
	else:
		_play("hit_enemy", -12.0, randf_range(0.9, 1.2))


# --- Ennemis et collisions ---------------------------------------------------

func _update_enemies(delta: float) -> void:
	# Séparation entre ennemis : sans elle, la horde se fond en un seul point.
	var n := enemies.size()
	var push: Array[Vector3] = []
	push.resize(n)
	push.fill(Vector3.ZERO)
	for i in n:
		var a: Node3D = enemies[i]
		for j in range(i + 1, n):
			var b: Node3D = enemies[j]
			var v := a.position - b.position
			v.y = 0
			var min_d: float = a.radius + b.radius
			var d2 := v.length_squared()
			if d2 < min_d * min_d and d2 > 0.0001:
				var d := sqrt(d2)
				var f := v / d * (min_d - d) * 6.0
				push[i] += f
				push[j] -= f
	for i in n:
		var e: Node3D = enemies[i]
		push[i] += _avoid_obstacles(e)
		var dmg: float = e.step(delta, mech.position, push[i])
		e.position = _resolve(e.position, e.radius)
		if dmg > 0.0 and mech.take_damage(dmg):
			hurt_vignette = 1.0
			_shake = 1.0
			_play("player_hurt", -4.0)


# Contournement : un obstacle droit devant pousse l'ennemi sur le côté. Sans
# cela, un ennemi aligné derrière un pilier reste plaqué contre lui.
func _avoid_obstacles(e: Node3D) -> Vector3:
	var q := Vector2(e.position.x, e.position.z)
	var to_target := Vector2(mech.position.x, mech.position.z) - q
	if to_target.length() < 0.1:
		return Vector3.ZERO
	var dir := to_target.normalized()
	var side := Vector2.ZERO
	for o in obstacles:
		var v: Vector2 = o.p - q
		var ahead := v.dot(dir)
		if ahead <= 0.0 or ahead > to_target.length():
			continue
		var lateral := v.dot(Vector2(-dir.y, dir.x))
		var clear: float = o.r + e.radius + 0.6
		if absf(lateral) < clear and v.length() < clear + 3.0:
			side += Vector2(-dir.y, dir.x) * (-signf(lateral) if lateral != 0.0 else 1.0) * e.speed * 1.5
	return Vector3(side.x, 0, side.y)


# Repousse un cercle hors des obstacles et le garde dans l'arène.
func _resolve(p: Vector3, r: float) -> Vector3:
	var q := Vector2(p.x, p.z)
	for o in obstacles:
		var v: Vector2 = q - o.p
		var min_d: float = o.r + r
		var d := v.length()
		if d < min_d:
			q = o.p + (v / maxf(d, 0.001)) * min_d
	if q.length() > ARENA_RADIUS - r:
		q = q.normalized() * (ARENA_RADIUS - r)
	return Vector3(q.x, p.y, q.y)


func _spawn_enemy() -> void:
	var kind := "walker"
	if wave >= 3 and _to_spawn % 7 == 0:
		kind = "brute"
	elif wave >= 2 and randf() < 0.3:
		kind = "runner"
	var e: Node3D = EnemyScript.new()
	add_child(e)
	e.setup(kind, 1.0 + 0.12 * (wave - 1))
	var pos := Vector3.ZERO
	for attempt in 12:
		var ang := randf() * TAU
		var rad := randf_range(24.0, ARENA_RADIUS - 3.0)
		pos = Vector3(cos(ang) * rad, 0, sin(ang) * rad)
		if pos.distance_to(mech.position) > 16.0:
			break
	e.position = _resolve(pos, e.radius)
	enemies.append(e)
	if randf() < 0.35:
		_play("enemy_groan", -14.0, randf_range(0.8, 1.1))


# --- Vagues et états ---------------------------------------------------------

func remaining() -> int:
	return enemies.size() + _to_spawn


func _update_waves(delta: float) -> void:
	if _intermission > 0.0:
		_intermission -= delta
		if _intermission <= 0.0:
			_next_wave()
		return
	if _to_spawn > 0:
		_spawn_cd -= delta
		if _spawn_cd <= 0.0 and enemies.size() < MAX_ALIVE:
			_spawn_cd = maxf(0.25, 0.9 - wave * 0.06)
			_spawn_enemy()
			_to_spawn -= 1
	elif enemies.is_empty():
		if smoke and wave >= SMOKE_LAST_WAVE:
			print("[smoke] OK : vague %d conclue, %d détruits, %.0f s de jeu" % [wave, kills, _time])
			get_tree().quit()
			return
		_intermission = 3.0
		mech.hp = minf(mech.hp + 15.0, mech.MAX_HP)
		_show_banner("VAGUE %d TERMINÉE" % wave, 2.5)


func _next_wave() -> void:
	wave += 1
	_to_spawn = 5 + wave * 2
	_spawn_cd = 0.5
	_show_banner("VAGUE %d" % wave, 2.0)
	if smoke:
		print("[smoke] vague %d : %d ennemis, %d bullets en vol" % [wave, _to_spawn, bullets.size()])


func in_play() -> bool:
	return state == State.PLAYING or state == State.PAUSED


func _start_game() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	mech.reset()
	cam_pitch = -0.2
	wave = 0
	kills = 0
	_to_spawn = 0
	_intermission = 0.0
	_firing = false
	state = State.PLAYING
	_overlay.visible = false
	_capture_mouse()
	if _music and not _music.playing:
		_music.play()
	_next_wave()


func _resume_or_start() -> void:
	match state:
		State.TITLE, State.OVER:
			_start_game()
		State.PAUSED:
			state = State.PLAYING
			_overlay.visible = false
			_capture_mouse()


func _pause() -> void:
	state = State.PAUSED
	_firing = false
	_title.text = "PAUSE"
	_subtitle.text = "Cliquer pour reprendre"
	_body.text = ""
	_overlay.visible = true


func _game_over() -> void:
	state = State.OVER
	_firing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Shapes.burst(self, mech.position + Vector3(0, 2, 0), Color(1, 0.5, 0.1), 40, 12.0, 0.35)
	_play("game_over", -2.0)
	_title.text = "MECH DÉTRUIT"
	_subtitle.text = "Vague %d  ·  %d ennemis détruits" % [wave, kills]
	_body.text = "Cliquer ou toucher pour recommencer"
	_overlay.visible = true


# --- Monde -------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.07, 0.16)
	sky_mat.sky_horizon_color = Color(0.55, 0.32, 0.25)
	sky_mat.ground_horizon_color = Color(0.3, 0.2, 0.17)
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.06)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.22, 0.22)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(35.0), 0)
	sun.light_color = Color(1.0, 0.82, 0.68)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	ground.mesh = plane
	var gm := ShaderMaterial.new()
	gm.shader = GroundShader
	ground.material_override = gm
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	_build_walls()
	_build_obstacles()


func _build_walls() -> void:
	# Enceinte en ruine : un cercle de blocs de hauteur irrégulière.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var stone := Shapes.mat(Color(0.3, 0.28, 0.27), 0.0, 0.95)
	var count := 56
	for i in count:
		var ang := TAU * i / count
		var h := rng.randf_range(2.5, 6.5)
		if i % 9 == 0:
			h = 11.0  # tours
		var seg := Shapes.box(self, Vector3(5.6, h, 2.2), Vector3(cos(ang), 0, sin(ang)) * (ARENA_RADIUS + 1.5) + Vector3(0, h / 2, 0), stone)
		seg.rotation.y = -ang + PI / 2


func _build_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stone := Shapes.mat(Color(0.38, 0.35, 0.33), 0.0, 0.9)
	var dark := Shapes.mat(Color(0.2, 0.19, 0.19), 0.0, 1.0)
	var crate := Shapes.mat(Color(0.4, 0.27, 0.16), 0.0, 0.85)
	var placed := 0
	while placed < 18:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(10.0, ARENA_RADIUS - 6.0)
		var p := Vector2(cos(ang), sin(ang)) * rad
		var ok := true
		for o in obstacles:
			if p.distance_to(o.p) < o.r + 5.0:
				ok = false
		if not ok:
			continue
		placed += 1
		var kind := placed % 3
		if kind == 0:
			# Pilier brisé.
			var h := rng.randf_range(3.0, 8.0)
			Shapes.cylinder(self, 1.2, h, Vector3(p.x, h / 2, p.y), stone, 10)
			Shapes.cylinder(self, 1.5, 0.6, Vector3(p.x, 0.3, p.y), dark, 10)
			obstacles.append({"p": p, "r": 1.5, "h": h})
		elif kind == 1:
			# Bloc effondré.
			var s := rng.randf_range(1.8, 3.2)
			var b := Shapes.box(self, Vector3(s * 1.4, s, s), Vector3(p.x, s / 2 - 0.2, p.y), stone)
			b.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
			obstacles.append({"p": p, "r": s * 0.85, "h": s})
		else:
			# Caisses empilées.
			Shapes.box(self, Vector3(1.8, 1.8, 1.8), Vector3(p.x, 0.9, p.y), crate).rotation.y = rng.randf() * TAU
			Shapes.box(self, Vector3(1.4, 1.4, 1.4), Vector3(p.x + 0.2, 2.5, p.y - 0.1), crate).rotation.y = rng.randf() * TAU
			obstacles.append({"p": p, "r": 1.4, "h": 3.2})
	# Quatre braseros près du centre : ce sont eux qui éclairent l'arène de nuit.
	for i in 4:
		var ang := TAU * i / 4 + PI / 4
		var p := Vector3(cos(ang), 0, sin(ang)) * 16.0
		Shapes.cylinder(self, 0.6, 1.2, p + Vector3(0, 0.6, 0), dark, 8)
		Shapes.box(self, Vector3(0.7, 0.5, 0.7), p + Vector3(0, 1.45, 0), Shapes.glow_mat(Color(1.0, 0.5, 0.15), 3.0))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.light_energy = 2.2
		light.omni_range = 16.0
		light.position = p + Vector3(0, 2.2, 0)
		add_child(light)
		obstacles.append({"p": Vector2(p.x, p.z), "r": 0.8, "h": 1.7})


# --- Interface et son ------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
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
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	_title = _label(box, 64, Color(1, 0.8, 0.4))
	_subtitle = _label(box, 26, Color(1, 1, 1, 0.9))
	_body = _label(box, 18, Color(1, 1, 1, 0.7))

	var version := Label.new()
	version.text = _version_text()
	version.add_theme_font_size_override("font_size", 12)
	version.modulate.a = 0.5
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(8, -20)
	_overlay.add_child(version)


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func _show_overlay() -> void:
	_title.text = "MECHA SURVIVANT 3D"
	_subtitle.text = "Prototype — vue à la troisième personne"
	_body.text = "Cliquer pour jouer\n\nSouris : viser   ·   Clic gauche : tirer\nZQSD / WASD / flèches : marcher   ·   Espace : dash   ·   Échap : pause\n\nSur mobile : glisser à gauche pour marcher, à droite pour viser — le tir est automatique.\nLe radar en haut à droite montre ce qui arrive dans le dos (en rouge)."
	_overlay.visible = true


func _show_banner(text: String, duration: float) -> void:
	_banner.text = text
	_banner_t = duration


func _version_text() -> String:
	if FileAccess.file_exists("res://version.txt"):
		return "proto 3D · " + FileAccess.get_file_as_string("res://version.txt").strip_edges()
	return "proto 3D · dev"


func _setup_audio() -> void:
	for n in ["shoot", "hit_enemy", "enemy_death", "player_hurt", "game_over", "dash", "enemy_groan"]:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	_music = AudioStreamPlayer.new()
	var music: AudioStreamMP3 = load("res://assets/music/dungeon.mp3")
	if music:
		music.loop = true
		_music.stream = music
		_music.volume_db = -10.0
	add_child(_music)


func _play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if smoke or not _streams.has(name):
		return
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
