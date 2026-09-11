class_name MainMenu
extends Control
## Choix de l'arène : difficulté, élément des monstres, accès à la forge.

signal start_requested
signal shop_requested

var _diff_buttons := {}
var _elem_buttons := {}
var _trait: Label
var _equip: Label
var _hints: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := UiTheme.label("Hell's Survivant II", 46, UiTheme.GOLD, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UiTheme.label("Choisis ton arène", 20, UiTheme.EMBER, 4)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	box.add_child(_section("Difficulté"))
	var diffs := HBoxContainer.new()
	diffs.alignment = BoxContainer.ALIGNMENT_CENTER
	diffs.add_theme_constant_override("separation", 12)
	box.add_child(diffs)
	for id in Data.DIFFICULTY_ORDER:
		var b := UiTheme.button(Data.DIFFICULTIES[id]["label"], Vector2(160, 38))
		b.toggle_mode = true
		b.pressed.connect(_pick_difficulty.bind(id))
		diffs.add_child(b)
		_diff_buttons[id] = b

	box.add_child(_section("Élément des monstres"))
	var grid_center := CenterContainer.new()
	box.add_child(grid_center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid_center.add_child(grid)
	for id in Data.ELEMENT_ORDER:
		var elem: Dictionary = Data.ELEMENTS[id]
		var b := UiTheme.button(elem["label"], Vector2(168, 48))
		b.icon = load("res://assets/sprites/monsters/%s.png" % elem["sprite"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		var glow: Color = elem["glow"]
		var color: Color = elem["color"]
		var selected := UiTheme.button_style(color.darkened(0.3), glow)
		selected.set_border_width_all(3)
		b.add_theme_stylebox_override("pressed", selected)
		b.add_theme_stylebox_override("hover_pressed", selected)
		b.pressed.connect(_pick_element.bind(id))
		grid.add_child(b)
		_elem_buttons[id] = b
	_trait = UiTheme.label("", 15, UiTheme.MUTED)
	_trait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_trait)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	box.add_child(actions)
	var start := UiTheme.button("Entrer dans l'arène", Vector2(250, 52), 20)
	start.pressed.connect(func() -> void:
		Audio.sfx("click")
		start_requested.emit())
	actions.add_child(start)
	var shop := UiTheme.button("Forge infernale", Vector2(250, 52), 20)
	shop.pressed.connect(func() -> void:
		Audio.sfx("click")
		shop_requested.emit())
	actions.add_child(shop)

	_equip = UiTheme.label("", 14, UiTheme.MUTED)
	_equip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_equip)
	_hints = UiTheme.label("", 13, UiTheme.MUTED)
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hints)

	var version := UiTheme.label(GameVersion.read(), 12, UiTheme.MUTED)
	add_child(version)
	version.set_anchor_and_offset(SIDE_LEFT, 0.0, 10)
	version.set_anchor_and_offset(SIDE_TOP, 1.0, -24)
	version.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0)
	refresh()

func _section(text: String) -> Label:
	var l := UiTheme.label(text, 18, Color.WHITE, 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _pick_difficulty(id: String) -> void:
	Game.difficulty = id
	Audio.sfx("click")
	refresh()

func _pick_element(id: String) -> void:
	Game.element = id
	Audio.sfx("click")
	refresh()

func refresh() -> void:
	if _trait == null:
		return
	for id in _diff_buttons:
		(_diff_buttons[id] as Button).set_pressed_no_signal(id == Game.difficulty)
	for id in _elem_buttons:
		(_elem_buttons[id] as Button).set_pressed_no_signal(id == Game.element)
	var elem := Game.elem()
	var tag := "  —  boss final en vague %d" % Data.FINAL_BOSS_WAVE if Game.element == Data.FINAL_BOSS_ELEMENT else ""
	_trait.text = "%s : %s%s" % [elem["label"], elem["trait"], tag]
	_equip.text = "Équipement : %s — %s — Or : %d" % [Save.sword()["name"], Save.armor()["name"], Save.gold]
	_hints.text = "QD : difficulté — ZS : élément — Entrée : combattre — I : forge — M : %s" % (
		"réactiver le son" if Save.muted else "couper le son")

## Commandes clavier de la v1. Les éléments sont 7 : la v1 bouclait sur 6 et
## sautait l'Ombre au clavier.
func handle_key(key: Key) -> void:
	var d := Data.DIFFICULTY_ORDER.find(Game.difficulty)
	var e := Data.ELEMENT_ORDER.find(Game.element)
	var nd := Data.DIFFICULTY_ORDER.size()
	var ne := Data.ELEMENT_ORDER.size()
	match key:
		KEY_Q, KEY_LEFT:
			Game.difficulty = Data.DIFFICULTY_ORDER[(d - 1 + nd) % nd]
		KEY_D, KEY_RIGHT:
			Game.difficulty = Data.DIFFICULTY_ORDER[(d + 1) % nd]
		KEY_Z, KEY_UP:
			Game.element = Data.ELEMENT_ORDER[(e - 1 + ne) % ne]
		KEY_S, KEY_DOWN:
			Game.element = Data.ELEMENT_ORDER[(e + 1) % ne]
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			start_requested.emit()
			return
		_:
			return
	refresh()
