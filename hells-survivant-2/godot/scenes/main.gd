extends Node
## Point d'entrée : arène en fond, écrans d'interface par-dessus, commandes
## clavier de la v1.
##
## Mode smoke : `godot --headless --path godot -- --smoke [--element=X]
## [--difficulty=X] [--wave=N] [--duration=S]` joue une partie accélérée sans
## rendu puis quitte, avec un code de sortie non nul en cas d'échec. Le héros y
## est immortel, équipé au maximum, et combat tout seul.

const SMOKE_TIME_SCALE := 8.0

var world: World
var menu: MainMenu
var hud: Hud
var shop: Shop
var end_screen: EndScreen

var _smoke_left := 0.0
var _smoke_start_wave := 1
var _smoke_expect_victory := false
var _smoke_done := false

func _ready() -> void:
	randomize()
	_register_inputs()
	world = World.new()
	add_child(world)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Hud.new()
	hud.world = world
	root.add_child(hud)
	menu = MainMenu.new()
	root.add_child(menu)
	shop = Shop.new()
	shop.world = world
	root.add_child(shop)
	end_screen = EndScreen.new()
	root.add_child(end_screen)

	menu.start_requested.connect(func() -> void: world.start_run())
	menu.shop_requested.connect(Game.open_shop)
	shop.closed.connect(Game.close_shop)
	end_screen.back_requested.connect(_back_to_menu)
	Game.state_changed.connect(_on_state)
	_on_state(Game.state)
	Audio.play_music("menu")
	_start_smoke_if_asked()

func _register_inputs() -> void:
	var map := {
		"move_up": [KEY_Z, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_Q, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.keycode = key
			InputMap.action_add_event(action, ev)

func _on_state(s: String) -> void:
	var from_play := Game.shop_return_state == "playing"
	menu.visible = s == "menu" or (s == "shop" and not from_play)
	hud.visible = s in ["playing", "gameover", "victory"] or (s == "shop" and from_play)
	shop.visible = s == "shop"
	end_screen.visible = s in ["gameover", "victory"]
	if menu.visible:
		menu.refresh()
	if shop.visible:
		shop.refresh()
	if end_screen.visible:
		end_screen.present(s == "victory")

func _back_to_menu() -> void:
	world.clear_run()
	world.reset_player()
	Game.set_state("menu")
	Audio.play_music("menu")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Game.state == "playing":
			world.attack_toward(world.get_global_mouse_position())
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := (event as InputEventKey).keycode
	if Game.state == "menu" and not event.is_echo():
		menu.handle_key(key)
	elif Game.state == "playing" and key == KEY_SPACE:
		world.do_attack()
	if event.is_echo():
		return
	if key == KEY_I and Game.state in ["playing", "shop", "menu"]:
		if Game.state == "shop":
			Game.close_shop()
		else:
			Game.open_shop()
	elif key == KEY_ESCAPE and Game.state == "shop":
		Game.close_shop()
	elif key in [KEY_ENTER, KEY_KP_ENTER] and Game.state in ["gameover", "victory"]:
		_back_to_menu()
	elif key == KEY_M:
		Audio.toggle_mute()
		menu.refresh()

# ---------------------------------------------------------------------------
# Mode smoke
# ---------------------------------------------------------------------------

func _start_smoke_if_asked() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--smoke" in args:
		return
	Game.smoke_test = true
	Engine.time_scale = SMOKE_TIME_SCALE
	_smoke_left = 20.0
	for a in args:
		if a.begins_with("--wave="):
			_smoke_start_wave = int(a.trim_prefix("--wave="))
		elif a.begins_with("--element="):
			Game.element = a.trim_prefix("--element=")
		elif a.begins_with("--difficulty="):
			Game.difficulty = a.trim_prefix("--difficulty=")
		elif a.begins_with("--duration="):
			_smoke_left = float(a.trim_prefix("--duration="))
	# En mémoire seulement : Save.write() ne fait rien en mode smoke.
	Save.sword_tier = Data.SWORDS.size() - 1
	Save.armor_tier = Data.ARMORS.size() - 1
	_smoke_expect_victory = Data.is_final_boss_wave(Game.element, _smoke_start_wave)
	print("[smoke] %s / %s, départ vague %d" % [Game.element, Game.difficulty, _smoke_start_wave])
	Game.open_shop()
	Game.close_shop()
	world.start_run(_smoke_start_wave)

func _process(delta: float) -> void:
	if not Game.smoke_test or _smoke_done:
		return
	_drive_smoke_player()
	_smoke_left -= delta / Engine.time_scale
	if Game.state != "victory" and _smoke_left > 0.0:
		return
	_smoke_done = true
	var ok := Game.state == "victory" if _smoke_expect_victory else Game.wave > _smoke_start_wave
	print("[smoke] %s — état : %s, vague atteinte : %d, ennemis vivants : %d, or gagné : %d" % [
		"OK" if ok else "ÉCHEC", Game.state, Game.wave, world.enemies.size(), Game.run_gold])
	get_tree().quit(0 if ok else 1)

## Pilote automatique : marche sur l'ennemi le plus proche et frappe.
func _drive_smoke_player() -> void:
	var p := world.player
	p.hp = p.max_hp
	world.smoke_dir = Vector2.ZERO
	if Game.state != "playing":
		return
	var nearest: Enemy = null
	var best := INF
	for e in world.enemies:
		var d := e.position.distance_to(p.position)
		if d < best:
			best = d
			nearest = e
	if nearest == null:
		return
	var to := nearest.position - p.position
	if to.length() > float(Save.sword()["range"]) * 0.7:
		world.smoke_dir = to.normalized()
	if to != Vector2.ZERO:
		p.facing = to.normalized()
	world.do_attack()
