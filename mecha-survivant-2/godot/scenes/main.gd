extends Node
## Point d'entrée : enchaîne écran-titre → arène → écran d'upgrade → fin.
##
## Mode smoke test : `godot --headless --path godot -- --smoke [--wave=N]` joue
## une partie en accéléré sans rendu, puis quitte. C'est le test de
## non-régression du dépôt (spawns, vagues, boss) sur une machine sans écran.
## Le joueur y est immortel et tire tout seul, sinon rien n'irait plus loin que
## la première vague.

const SMOKE_DURATION := 25.0
const SMOKE_TIME_SCALE := 8.0

var arena: Arena
var hud: Hud
var start_screen: StartScreen
var upgrade_screen: UpgradeScreen
var game_over_screen: GameOverScreen

var _smoke_left := SMOKE_DURATION

func _ready() -> void:
	randomize()
	arena = Arena.new()
	add_child(arena)
	hud = Hud.new()
	hud.player = arena.player
	add_child(hud)
	start_screen = StartScreen.new()
	add_child(start_screen)
	upgrade_screen = UpgradeScreen.new()
	add_child(upgrade_screen)
	game_over_screen = GameOverScreen.new()
	add_child(game_over_screen)

	start_screen.start_requested.connect(_begin_game)
	start_screen.titan_test_requested.connect(_begin_titan_test)
	upgrade_screen.upgrade_chosen.connect(_on_upgrade_chosen)
	game_over_screen.restart_requested.connect(_back_to_title)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.player_died.connect(_on_player_died)

	AudioManager.play_music("menu")
	_expose_debug_bridge()

	var args := OS.get_cmdline_user_args()
	if "--smoke" in args:
		GameState.smoke_test = true
		Engine.time_scale = SMOKE_TIME_SCALE
		var wave := 1
		for a in args:
			if a.begins_with("--wave="):
				wave = int(a.trim_prefix("--wave="))
		if "--titan" in args:
			print("[smoke] départ : Titan en phase finale")
			_begin_titan_test()
		else:
			print("[smoke] départ vague %d" % wave)
			_begin_game(wave)

func _process(delta: float) -> void:
	if not GameState.smoke_test:
		return
	_drive_smoke_player(delta)
	_smoke_left -= delta / Engine.time_scale
	if _smoke_left <= 0.0:
		print("[smoke] terminé — vague atteinte : %d, ennemis vivants : %d"
			% [GameState.wave, get_tree().get_nodes_in_group("enemies").size()])
		get_tree().quit()

## Pilote automatique : le mech reste debout et arrose l'ennemi le plus proche,
## pour que la simulation atteigne vraiment les boss.
func _drive_smoke_player(delta: float) -> void:
	var p := arena.player
	if p == null or not p.alive:
		return
	p.hp = p.max_hp
	p.invuln = maxf(p.invuln, 0.05)
	var nearest: Node2D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyBase
		if enemy == null or not enemy.alive or enemy.is_damage_immune():
			continue
		var d := enemy.global_position.distance_to(p.global_position)
		if d < best:
			best = d
			nearest = enemy
	if nearest == null:
		return
	p.fire_cd -= delta
	if p.fire_cd <= 0.0:
		p.fire_cd = p.fire_interval
		var aim := (nearest.global_position - p.global_position).normalized()
		var b := Bullet.new()
		b.setup(p.global_position, aim, p.bullet_damage)
		arena.add_child(b)

## En smoke, on enchaîne les vagues sans attendre un clic sur l'écran d'upgrade.
func _auto_pick_upgrade() -> void:
	var choices := UpgradeManager.draw_choices(arena.player)
	if choices.is_empty():
		return
	upgrade_screen.visible = false
	_on_upgrade_chosen(choices[0]["id"])

func _begin_game(start_wave: int) -> void:
	start_screen.visible = false
	game_over_screen.visible = false
	UpgradeManager.reset()
	arena.clear_transients()
	arena.player.reset_stats()
	arena.player.position = get_viewport().get_visible_rect().size * 0.5
	_apply_starting_scaling(start_wave)
	GameState.reset(start_wave)
	arena.waves.start_wave(start_wave)

## Démarrer plus loin qu'à la vague 1 accorde les pouvoirs qu'on aurait eus.
func _apply_starting_scaling(start_wave: int) -> void:
	for i in start_wave - 1:
		var choices := UpgradeManager.draw_choices(arena.player, 1)
		if not choices.is_empty():
			UpgradeManager.apply(choices[0]["id"], arena.player)

func _begin_titan_test() -> void:
	_begin_game(GameState.FINAL_WAVE)
	for e in get_tree().get_nodes_in_group("enemies"):
		var titan := e as Titan
		if titan != null:
			titan.jump_to_final_stand()

func _on_wave_cleared(n: int) -> void:
	if n >= GameState.FINAL_WAVE:
		GameState.running = false
		AudioManager.stop_music()
		game_over_screen.show_result(true, n)
		return
	if GameState.smoke_test:
		_auto_pick_upgrade()
		return
	upgrade_screen.present(UpgradeManager.draw_choices(arena.player))

func _on_upgrade_chosen(id: String) -> void:
	UpgradeManager.apply(id, arena.player)
	arena.clear_transients()
	arena.waves.start_wave(GameState.wave + 1)

func _on_player_died() -> void:
	GameState.running = false
	AudioManager.stop_music()
	game_over_screen.show_result(false, GameState.wave)

func _back_to_title() -> void:
	GameState.running = false
	arena.clear_transients()
	AudioManager.play_music("menu")
	start_screen.visible = true

## Crochet de débogage exposé au navigateur : la boucle de jeu vit dans le wasm,
## le pilotage image par image de `tools/driver.js` n'y a pas prise. On expose
## donc des commandes appelables depuis Chromium headless.
func _expose_debug_bridge() -> void:
	if not OS.has_feature("web"):
		return
	var bridge := JavaScriptBridge.get_interface("window")
	if bridge == null:
		return
	bridge.godotDebugReady = true
