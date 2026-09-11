class_name World
extends Node2D
## Arène, vagues et combat. La logique est celle de `hells-survivant/game.js`,
## exécutée à pas fixe de 1/60 s : les compteurs de la v1 (en frames) sont
## repris tels quels, seul le rendu suit la fréquence d'affichage.

const TICK := 1.0 / 60.0
const MAX_TICKS_PER_FRAME := 16
## Tuiles de 32 px dessinées en 64 : même texel que les créatures.
const TILE := 64
const LAVA_POOLS := 4

var player: Player
var enemies: Array[Enemy] = []
var projectiles: Array[Projectile] = []
var wave_intermission := 0
var enemies_to_spawn := 0
var spawn_timer := 0
## Direction imposée par le pilote automatique du mode smoke.
var smoke_dir := Vector2.ZERO

var entities: Node2D
var fx_layer: Node2D
var _camera: Camera2D
var _acc := 0.0
var _shake := 0.0
var _floor_tex: Array[Texture2D] = []
var _lava_tex: Array[Texture2D] = []
var _tiles := PackedInt32Array()
var _lava_cells := {}
var _lava_frame := 0
var _lava_timer := 0.0
var _lava_lights: Array[Fx.Glow] = []
var _cols := 0
var _rows := 0

func _ready() -> void:
	for i in 7:
		_floor_tex.append(load("res://assets/sprites/dungeon/floor_%d.png" % i))
	for i in 4:
		_lava_tex.append(load("res://assets/sprites/dungeon/lava_%d.png" % i))
	_cols = ceili(Data.ARENA.x / TILE)
	_rows = ceili(Data.ARENA.y / TILE)
	_build_ground()

	var dark := CanvasModulate.new()
	dark.color = Color(0.8, 0.68, 0.66)
	add_child(dark)
	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	fx_layer = Node2D.new()
	fx_layer.z_index = 10
	add_child(fx_layer)

	player = Player.new()
	player.position = Data.ARENA / 2.0
	entities.add_child(player)

func _build_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	_tiles.resize(_cols * _rows)
	for i in _tiles.size():
		_tiles[i] = rng.randi_range(0, 2) if rng.randf() < 0.8 else rng.randi_range(3, 6)
	var center := Data.ARENA / 2.0
	var placed := 0
	while placed < LAVA_POOLS:
		var c := Vector2i(rng.randi_range(1, _cols - 3), rng.randi_range(1, _rows - 3))
		var pos := Vector2(c) * TILE + Vector2(TILE, TILE)
		if pos.distance_to(center) < 220.0:
			continue
		# Petites flaques : en tuiles de 64 px, un bloc 3×3 écrasait l'arène.
		_lava_cells[c] = rng.randi_range(0, 3)
		for n in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if rng.randf() < 0.35:
				_lava_cells[c + n] = rng.randi_range(0, 3)
		var l := Fx.light(Color(1.0, 0.45, 0.1), 2.6, 0.9)
		l.position = pos - Vector2(TILE, TILE) / 2.0
		add_child(l)
		_lava_lights.append(l)
		placed += 1

func _draw() -> void:
	for y in _rows:
		for x in _cols:
			var cell := Vector2i(x, y)
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			if _lava_cells.has(cell):
				var phase: int = _lava_cells[cell]
				draw_texture_rect(_lava_tex[(phase + _lava_frame) % _lava_tex.size()], rect, false)
			else:
				draw_texture_rect(_floor_tex[_tiles[y * _cols + x]], rect, false)

func _process(delta: float) -> void:
	_lava_timer += delta
	if _lava_timer >= 0.35:
		_lava_timer = 0.0
		_lava_frame += 1
		queue_redraw()
	var now := Time.get_ticks_msec() * 0.004
	for l in _lava_lights:
		l.energy = 0.8 + 0.15 * sin(now + l.position.x)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	else:
		_camera.offset = Vector2.ZERO

	if Game.state != "playing":
		_acc = 0.0
		player.moving = false
		return
	_acc += delta
	var n := 0
	while _acc >= TICK and n < MAX_TICKS_PER_FRAME:
		_tick()
		_acc -= TICK
		n += 1
	if n >= MAX_TICKS_PER_FRAME:
		_acc = 0.0

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func current_boss() -> Enemy:
	for e in enemies:
		if e.is_boss:
			return e
	return null

func clear_run() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	for c in fx_layer.get_children():
		c.queue_free()

func reset_player() -> void:
	player.max_hp = Save.armor()["hp"]
	player.hp = player.max_hp
	player.position = Data.ARENA / 2.0
	player.burn_timer = 0
	player.attack_timer = 0
	player.attack_cooldown = 0
	player.facing = Vector2(0, 1)
	player.revive()
	player.refresh_equipment()

func start_run(start_wave := 1) -> void:
	clear_run()
	reset_player()
	Game.wave = start_wave
	wave_intermission = 60
	enemies_to_spawn = 0
	spawn_timer = 0
	Game.run_gold = 0
	Game.set_state("playing")
	Audio.play_music("combat")

func _tick() -> void:
	_update_player()
	_update_waves()
	_update_enemies()
	if Game.state == "playing":
		_update_projectiles()

# ---------------------------------------------------------------------------
# Joueur
# ---------------------------------------------------------------------------

func _update_player() -> void:
	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if Game.smoke_test:
		dir = smoke_dir
	player.moving = dir != Vector2.ZERO
	if player.moving:
		dir = dir.normalized()
		player.position += dir * player.speed
		if player.attack_timer <= 0:
			player.facing = dir
	player.position = player.position.clamp(Vector2.ONE * player.radius, Data.ARENA - Vector2.ONE * player.radius)

	if player.attack_timer > 0:
		player.attack_timer -= 1
	if player.attack_cooldown > 0:
		player.attack_cooldown -= 1
	if player.burn_timer > 0:
		player.burn_timer -= 1
		if player.burn_timer % 20 == 0:
			hit_player(2.0)

func attack_toward(target: Vector2) -> void:
	var to := target - player.position
	if to != Vector2.ZERO:
		player.facing = to.normalized()
	do_attack()

func do_attack() -> void:
	if Game.state != "playing" or player.attack_cooldown > 0 or player.attack_timer > 0:
		return
	var sword := Save.sword()
	var sword_dmg: float = sword["dmg"]
	var sword_range: float = sword["range"]
	player.attack_timer = 14
	player.attack_cooldown = 22
	player.start_swing(sword_range)
	Audio.sfx("attack")
	var facing_angle := player.facing.angle()
	# Copie : un ennemi tué quitte la liste pendant le parcours.
	for e: Enemy in enemies.duplicate():
		var d := e.position - player.position
		if d.length() > sword_range + e.radius:
			continue
		if absf(angle_difference(d.angle(), facing_angle)) < PI / 2.2:
			damage_enemy(e, sword_dmg)

func hit_player(raw_dmg: float) -> void:
	if Game.state != "playing":
		return
	var def: float = Save.armor()["def"]
	var dmg := raw_dmg * (1.0 - def)
	player.hp -= dmg
	player.hurt()
	shake(2.5)
	Fx.float_text(fx_layer, player.position + Vector2(0, -player.radius - 18), "-%d" % roundi(dmg), Color("#ff4444"))
	Audio.sfx("hit_player")
	if player.hp <= 0.0:
		player.hp = 0.0
		player.die()
		Game.set_state("gameover")
		Audio.stop_music()
		Audio.sfx("game_over", 0.55, 0.0)

# ---------------------------------------------------------------------------
# Vagues et ennemis
# ---------------------------------------------------------------------------

func _update_waves() -> void:
	if wave_intermission > 0:
		wave_intermission -= 1
		if wave_intermission == 0:
			_start_wave()
		return
	if enemies_to_spawn > 0:
		spawn_timer -= 1
		if spawn_timer <= 0:
			_spawn_enemy(false, false)
			enemies_to_spawn -= 1
			spawn_timer = 35
	if enemies.is_empty() and enemies_to_spawn == 0 and wave_intermission == 0:
		Game.wave += 1
		wave_intermission = 90
		Fx.float_text(fx_layer, Data.ARENA / 2.0 - Vector2(0, 40), "Vague %d dans 1,5s" % Game.wave, Color("#ffd23c"), true)

func _start_wave() -> void:
	if Data.is_final_boss_wave(Game.element, Game.wave) or Data.is_boss_wave(Game.wave):
		_spawn_enemy(true, Data.is_final_boss_wave(Game.element, Game.wave))
		enemies_to_spawn = 0
		Audio.play_music("boss")
		Audio.sfx("boss_warning")
		shake(5.0)
	else:
		enemies_to_spawn = Data.enemy_count(Game.wave)
		Audio.play_music("combat")
		Audio.sfx("wave_start")
	spawn_timer = 0

func _spawn_enemy(is_boss: bool, is_final: bool) -> void:
	var diff := Game.diff()
	var elem := Game.elem()
	var pos := Vector2.ZERO
	match randi() % 4:
		0: pos = Vector2(-30, randf() * Data.ARENA.y)
		1: pos = Vector2(Data.ARENA.x + 30, randf() * Data.ARENA.y)
		2: pos = Vector2(randf() * Data.ARENA.x, -30)
		_: pos = Vector2(randf() * Data.ARENA.x, Data.ARENA.y + 30)

	var wave_growth := 1.0 + Game.wave * 0.08
	var base_hp: float = 18.0 * elem["hp_mult"] * diff["hp_mult"] * wave_growth
	var base_dmg: float = 4.0 * elem["dmg_mult"] * diff["dmg_mult"]
	var base_speed: float = 1.3 * elem["speed_mult"]
	var hp_mult := 16.0 if is_final else (8.0 if is_boss else 1.0)
	var dmg_mult := 2.5 if is_final else (2.0 if is_boss else 1.0)
	var gold_base := 300.0 if is_final else (40.0 if is_boss else 4.0)
	var gold_mult: float = diff["gold_mult"]

	var e := Enemy.new()
	e.position = pos
	e.radius = 42.0 if is_final else (34.0 if is_boss else 15.0)
	e.hp = base_hp * hp_mult
	e.max_hp = e.hp
	e.dmg = base_dmg * dmg_mult
	e.speed = base_speed * 0.7 if is_boss else base_speed
	e.element = Game.element
	e.is_boss = is_boss
	e.is_final = is_final
	e.charge_timer = 180.0 + randf() * 60.0 if is_boss else 0.0
	e.gold_value = roundi(gold_base * gold_mult * (1.0 + Game.wave * 0.05))
	entities.add_child(e)
	enemies.append(e)

func damage_enemy(e: Enemy, amount: float) -> void:
	e.hp -= amount
	e.hit_flash = 8
	Fx.float_text(fx_layer, e.position + Vector2(0, -e.top() - 12), "-%d" % roundi(amount), Color.WHITE)
	Fx.sparks(fx_layer, e.position, e.glow)
	if e.hp <= 0.0:
		_kill_enemy(e)
	else:
		Audio.sfx("hit_enemy")

func _kill_enemy(e: Enemy) -> void:
	enemies.erase(e)
	Save.gold += e.gold_value
	Game.run_gold += e.gold_value
	Save.write()
	Fx.float_text(fx_layer, e.position, "+%d or" % e.gold_value, Color("#ffd23c"))
	Fx.gold_pop(fx_layer, e.position)
	Fx.puff(fx_layer, e.position, e.glow, e.sprite_scale)
	Audio.sfx("enemy_death")
	Audio.sfx("gold")
	e.die()
	if e.is_boss:
		shake(7.0)
	if e.is_final:
		Game.set_state("victory")
		Audio.stop_music()
		Audio.sfx("victory", 1.0, 0.0)

func _update_enemies() -> void:
	var elem := Game.elem()
	var ranged: bool = elem.get("ranged", false)
	var bricks: bool = elem.get("bricks", false)
	var lifesteal: float = elem.get("lifesteal", 0.0)
	var burn: bool = elem.get("burn", false)
	for e in enemies:
		if e.hit_flash > 0:
			e.hit_flash -= 1
		e.face_left = player.position.x < e.position.x

		if e.is_boss:
			e.charge_timer -= 1.0
			if e.charge_timer <= 0.0 and not e.charging:
				e.charging = true
				e.charge_telegraph = 45
				Audio.sfx("boss_charge")
			if e.charging:
				if e.charge_telegraph > 0:
					e.charge_telegraph -= 1
				else:
					var to_p := player.position - e.position
					var len_p := to_p.length() if to_p.length() > 0.0 else 1.0
					e.position += to_p / len_p * e.speed * 6.0
					e.charge_timer = 180.0 + randf() * 60.0
					e.charging = false
					shake(3.0)
				continue

		var to := player.position - e.position
		var dist := to.length() if to.length() > 0.0 else 1.0

		if ranged:
			const PREFERRED := 230.0
			if dist > PREFERRED + 30.0:
				e.position += to / dist * e.speed
			elif dist < PREFERRED - 30.0:
				# Écart assumé avec la v1 : le recul s'arrête au bord de l'arène,
				# sans quoi un tireur acculé sortait de l'écran pour de bon.
				var margin := Vector2.ONE * e.radius
				e.position = (e.position - to / dist * e.speed).clamp(margin, Data.ARENA - margin)
			if e.shoot_cooldown > 0:
				e.shoot_cooldown -= 1
			elif dist < 420.0:
				var p := Projectile.new()
				p.position = e.position
				p.velocity = to / dist * (3.2 if bricks else 4.5)
				p.dmg = e.dmg
				p.radius = (13.0 if bricks else 10.0) if e.is_boss else (9.0 if bricks else 6.0)
				p.brick = bricks
				entities.add_child(p)
				projectiles.append(p)
				e.shoot_cooldown = 55 if e.is_boss else 90
				if bricks:
					Audio.sfx("throw", 0.8)
			continue

		if dist > e.radius + player.radius:
			e.position += to / dist * e.speed
		elif e.attack_cooldown <= 0:
			hit_player(e.dmg)
			e.attack_cooldown = 50
			if lifesteal > 0.0:
				e.hp = minf(e.max_hp, e.hp + e.dmg * lifesteal)
			if burn:
				player.burn_timer = 120
		if e.attack_cooldown > 0:
			e.attack_cooldown -= 1
		if Game.state != "playing":
			return

func _update_projectiles() -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		p.position += p.velocity
		if p.brick:
			p.spin += 0.18
		if p.position.x < -20 or p.position.x > Data.ARENA.x + 20 or p.position.y < -20 or p.position.y > Data.ARENA.y + 20:
			projectiles.remove_at(i)
			p.queue_free()
			continue
		if p.position.distance_to(player.position) < p.radius + player.radius:
			projectiles.remove_at(i)
			Fx.sparks(fx_layer, p.position, Color(1, 0.3, 0.1) if p.brick else Color(0.7, 0.35, 1))
			p.queue_free()
			hit_player(p.dmg)
			if Game.state != "playing":
				return
