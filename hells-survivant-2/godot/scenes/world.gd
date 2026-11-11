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
## Conclave des boss : boss figés pendant l'annonce, fiole périodique (pas de
## vagues pour en faire tomber), écart minimal entre deux sprites de boss.
const RUSH_INTRO := 120
const RUSH_POTION_EVERY := 1200
const RUSH_GAP := 6.0
## Anneau d'apparition : centre un peu sous celui de l'arène et demi-axes,
## pour qu'aucun boss ne naisse sous la barre du HUD.
const RUSH_RING_CENTER := Vector2(450, 325)
const RUSH_RING := Vector2(330, 175)
## Bande du haut réservée au HUD (barre du Conclave) : un boss n'y monte pas,
## sinon son nom et sa barre de vie passeraient dessous.
const RUSH_HUD_TOP := 60.0

var player: Player
var enemies: Array[Enemy] = []
var projectiles: Array[Projectile] = []
## Fiole de soin au sol, une seule à la fois (voir `_drop_potion`).
var potion: Pickup = null
var wave_intermission := 0
var enemies_to_spawn := 0
var spawn_timer := 0
## Direction imposée par le pilote automatique du mode smoke.
var smoke_dir := Vector2.ZERO
## Conclave des boss : frames d'annonce restantes, frames de combat écoulées,
## nombre de boss et somme de leurs PV à l'apparition (barre du HUD).
var rush_intro := 0
var rush_ticks := 0
var rush_total := 0
var rush_max_hp := 0.0
var _rush_potion_timer := 0

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
	# Hors de `fx_layer`, que `clear_run` vide à chaque partie.
	var tags := BossTags.new()
	tags.world = self
	tags.z_index = 11
	add_child(tags)

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

static func boss_name(e: Enemy) -> String:
	return Data.final_boss(e.element)["name"] if e.is_final else Data.BOSS_NAMES[e.element]

## Boss de la vague en cours ou annoncée, "" s'il n'y en a pas. En Chaos, avant
## l'apparition, c'est la tête de file qui est annoncée.
func wave_boss_name() -> String:
	if Game.boss_rush:
		return Data.BOSS_RUSH["name"]
	var boss := current_boss()
	if boss:
		return boss_name(boss)
	if Data.is_final_boss_wave(Game.element, Game.wave):
		return Data.final_boss(Game.element)["name"]
	if not Data.is_boss_wave(Game.wave):
		return ""
	if Game.is_chaos():
		return "" if Game.boss_queue.is_empty() else Data.BOSS_NAMES[Game.boss_queue[0]]
	return Data.BOSS_NAMES[Game.element]

func clear_run() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	if potion != null:
		potion.queue_free()
		potion = null
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
	Game.boss_rush = false
	rush_intro = 0
	Game.boss_queue.clear()
	if Game.is_chaos():
		for id: String in Data.MOB_ELEMENTS:
			Game.boss_queue.append(id)
		Game.boss_queue.shuffle()
		# Départ en cours de partie (mode smoke) : les boss des vagues déjà
		# passées sont réputés tués.
		for _i in mini((start_wave - 1) / 5, Game.boss_queue.size()):
			Game.boss_queue.pop_front()
	Game.set_state("playing")
	Audio.play_music("combat")

func _tick() -> void:
	_update_player()
	if Game.boss_rush:
		_update_boss_rush()
	else:
		_update_waves()
	# Pendant l'annonce du Conclave, les boss restent figés en anneau.
	if rush_intro == 0:
		_update_enemies()
		if Game.boss_rush and Game.state == "playing":
			_wander_bosses()
			_separate_bosses()
	_update_potion()
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
			var element: String = Data.MOB_ELEMENTS.pick_random() if Game.is_chaos() else Game.element
			_spawn_enemy(element, false, false)
			enemies_to_spawn -= 1
			spawn_timer = 35
	if enemies.is_empty() and enemies_to_spawn == 0 and wave_intermission == 0:
		Game.wave += 1
		wave_intermission = 90
		Fx.float_text(fx_layer, Data.ARENA / 2.0 - Vector2(0, 40), "Vague %d dans 1,5s" % Game.wave, Color("#ffd23c"), true)

func _start_wave() -> void:
	var is_final := Data.is_final_boss_wave(Game.element, Game.wave)
	var boss_element := Game.element if is_final else _next_boss_element()
	if boss_element != "":
		_spawn_enemy(boss_element, true, is_final)
		if Game.smoke_test:
			print("[smoke] vague %d : %s" % [Game.wave, wave_boss_name()])
		enemies_to_spawn = 0
		Audio.play_music("boss")
		Audio.sfx("boss_warning")
		shake(5.0)
	else:
		enemies_to_spawn = Data.enemy_count(Game.wave)
		Audio.play_music("combat")
		Audio.sfx("wave_start")
	spawn_timer = 0
	_drop_potion()

## Élément du boss de cette vague, "" s'il n'y en a pas. En Chaos, le boss
## quitte la file à son apparition : la vague ne finit qu'à sa mort.
func _next_boss_element() -> String:
	if not Data.is_boss_wave(Game.wave):
		return ""
	if Game.is_chaos():
		return "" if Game.boss_queue.is_empty() else Game.boss_queue.pop_front()
	return Game.element

## Une fiole par vague, jamais deux au sol : celle qu'on a laissée traîner tient
## lieu de réserve pour la vague suivante.
func _drop_potion() -> void:
	if potion != null:
		return
	var margin := 90.0
	var pos := Vector2.ZERO
	# Ni sur le héros, ni dans un coin : quelques essais suffisent à trouver
	# un emplacement atteignable sans traverser toute l'arène.
	for _i in 12:
		pos = Vector2(randf_range(margin, Data.ARENA.x - margin), randf_range(margin, Data.ARENA.y - margin))
		if pos.distance_to(player.position) > 140.0:
			break
	potion = Pickup.new()
	potion.position = pos
	entities.add_child(potion)

## Le soin ne se déclenche qu'à PV entamés : à pleine vie, la fiole reste au sol
## plutôt que d'être gâchée en passant dessus.
func _update_potion() -> void:
	if potion == null or Game.state != "playing":
		return
	if player.hp >= player.max_hp:
		return
	if player.position.distance_to(potion.position) > potion.radius + player.radius:
		return
	var healed := minf(player.max_hp * potion.heal_ratio, player.max_hp - player.hp)
	player.hp += healed
	Fx.float_text(fx_layer, player.position + Vector2(0, -player.radius - 18), "+%d PV" % roundi(healed), Color("#5ee06a"))
	Fx.sparks(fx_layer, potion.position, Color("#ff4455"))
	Audio.sfx("purchase", 1.15)
	potion.queue_free()
	potion = null

func _spawn_enemy(element: String, is_boss: bool, is_final: bool) -> Enemy:
	var diff := Game.diff()
	var elem: Dictionary = Data.ELEMENTS[element]
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
	e.element = element
	e.is_boss = is_boss
	e.is_final = is_final
	e.charge_timer = 180.0 + randf() * 60.0 if is_boss else 0.0
	# Écart assumé avec la v1 (+5 %/vague) : +12 % rend l'équipement de la forge
	# atteignable sans enchaîner les parties.
	e.gold_value = roundi(gold_base * gold_mult * (1.0 + Game.wave * 0.12))
	if is_final and Data.final_boss(element).has("gold"):
		e.gold_value = Data.final_boss(element)["gold"]
	entities.add_child(e)
	enemies.append(e)
	return e

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
	# Conclave : seule la chute du dernier boss compte, boss finals compris.
	var won := current_boss() == null if Game.boss_rush else e.is_final
	if won and Game.state == "playing":
		Game.set_state("victory")
		Audio.stop_music()
		Audio.sfx("victory", 1.0, 0.0)

func _update_enemies() -> void:
	var shoot_mult: float = Game.diff()["shoot_mult"]
	for e in enemies:
		# Par monstre : en Chaos, les éléments se côtoient dans la même vague.
		var elem: Dictionary = Data.ELEMENTS[e.element]
		var ranged: bool = elem.get("ranged", false)
		var bricks: bool = elem.get("bricks", false)
		var lifesteal: float = elem.get("lifesteal", 0.0)
		var burn: bool = elem.get("burn", false)
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
				e.shoot_cooldown = roundi((55 if e.is_boss else 90) * shoot_mult)
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

# ---------------------------------------------------------------------------
# Conclave des boss
# ---------------------------------------------------------------------------

## Niveau spécial : tous les boss en même temps, disposés en anneau autour du
## héros. Chacun garde son comportement (mêlée, tir, charge, brûlure, vol de
## vie) ; s'y ajoutent une promenade autour du héros et une séparation qui
## empêche deux boss de se superposer. Pas de vagues : la partie est gagnée
## quand le dernier boss tombe.
func start_boss_rush() -> void:
	start_run(Data.BOSS_RUSH["wave"])
	Game.boss_rush = true
	wave_intermission = 0
	rush_intro = RUSH_INTRO
	rush_ticks = 0
	_rush_potion_timer = 0
	rush_max_hp = 0.0
	var roster := Data.BOSS_RUSH_ROSTER
	var names: Array[String] = []
	for i in roster.size():
		var element: String = roster[i][0]
		var is_final: bool = roster[i][1]
		var e := _spawn_enemy(element, true, is_final)
		# Décalage d'un demi-pas : aucun boss pile en haut, sous la barre du HUD.
		var a := -PI / 2.0 + TAU * (i + 0.5) / roster.size()
		e.position = RUSH_RING_CENTER + Vector2(cos(a), sin(a)) * RUSH_RING
		# Charges étalées : sinon les neuf boss chargeraient presque ensemble.
		e.charge_timer = 120.0 + randf() * 240.0
		Fx.puff(fx_layer, e.position, e.glow, e.sprite_scale)
		rush_max_hp += e.max_hp
		names.append(boss_name(e))
	rush_total = roster.size()
	Audio.play_music("boss")
	if Game.smoke_test:
		print("[smoke] conclave : %d boss — %s" % [rush_total, ", ".join(names)])

func _update_boss_rush() -> void:
	if rush_intro > 0:
		rush_intro -= 1
		if rush_intro == 0:
			Audio.sfx("boss_warning")
			shake(6.0)
			_drop_potion()
		return
	rush_ticks += 1
	_rush_potion_timer += 1
	if _rush_potion_timer >= RUSH_POTION_EVERY:
		_rush_potion_timer = 0
		_drop_potion()

## Pas de côté autour du héros, dont le sens s'inverse lentement et diffère
## d'un boss à l'autre : les boss rôdent au lieu de converger en tas.
func _wander_bosses() -> void:
	for e in enemies:
		if not e.is_boss or e.charging:
			continue
		var to := player.position - e.position
		if to == Vector2.ZERO:
			continue
		var phase := float(e.get_instance_id() % 628) * 0.01
		var side := sin(rush_ticks * 0.008 + phase)
		e.position += to.normalized().orthogonal() * side * e.speed * 0.8

## Écarte deux boss dont les sprites se chevauchent. La distance minimale suit
## la taille du sprite (`top()`), pas la hitbox de la v1, bien plus petite :
## c'est ce qui garde chaque boss lisible. Quelques passes suffisent à résorber
## les chevauchements en chaîne autour du héros.
func _separate_bosses() -> void:
	var bosses: Array[Enemy] = []
	for e in enemies:
		if e.is_boss:
			bosses.append(e)
	for _pass in 4:
		for i in bosses.size():
			for j in range(i + 1, bosses.size()):
				var a := bosses[i]
				var b := bosses[j]
				var min_d := a.top() + b.top() + RUSH_GAP
				var d := b.position - a.position
				var len := d.length()
				if len >= min_d:
					continue
				var n := d / len if len > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
				var push := (min_d - len) / 2.0
				a.position -= n * push
				b.position += n * push
		for e in bosses:
			var lo := Vector2(e.top(), e.top() + RUSH_HUD_TOP)
			e.position = e.position.clamp(lo, Data.ARENA - Vector2.ONE * e.top())

## Pire chevauchement entre deux sprites de boss, en pixels ; négatif, c'est
## l'écart entre les deux boss les plus proches (−RUSH_GAP quand ils se
## touchent à la limite). Mesuré par le mode smoke pour vérifier la séparation.
func boss_overlap() -> float:
	var worst := -INF
	for i in enemies.size():
		var a := enemies[i]
		if not a.is_boss:
			continue
		for j in range(i + 1, enemies.size()):
			var b := enemies[j]
			if b.is_boss:
				worst = maxf(worst, a.top() + b.top() - a.position.distance_to(b.position))
	return worst
