class_name Hud
extends Control
## Vie, or, vague, raccourcis, barre du boss et annonce de vague.

var world: World

var _hp_bar: ProgressBar
var _hp_label: Label
var _gold: Label
var _wave: Label
var _mode: Label
var _sound: Label
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _banner: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var left := PanelContainer.new()
	left.position = Vector2(12, 12)
	var ls := UiTheme.panel_style(Color(0.1, 0.04, 0.03, 0.82))
	ls.set_content_margin_all(8)
	ls.set_border_width_all(2)
	left.add_theme_stylebox_override("panel", ls)
	add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 3)
	left.add_child(lbox)
	_hp_bar = UiTheme.bar(Color("#b3202a"), Vector2(220, 22))
	lbox.add_child(_hp_bar)
	_hp_label = UiTheme.label("", 14, Color.WHITE, 4)
	_hp_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_bar.add_child(_hp_label)
	var gold_row := HBoxContainer.new()
	lbox.add_child(gold_row)
	var gold_icon := TextureRect.new()
	gold_icon.texture = load("res://assets/sprites/fx/gold.png")
	gold_icon.custom_minimum_size = Vector2(24, 24)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_row.add_child(gold_icon)
	_gold = UiTheme.label("", 16, Color("#ffd23c"), 3)
	gold_row.add_child(_gold)
	_wave = UiTheme.label("", 15, UiTheme.PARCH, 3)
	lbox.add_child(_wave)
	_mode = UiTheme.label("", 13, UiTheme.MUTED, 3)
	lbox.add_child(_mode)

	# Ancres posées après add_child : avant, la marge était recalculée contre un
	# parent de taille nulle et le bloc sortait de l'écran.
	var right := VBoxContainer.new()
	add_child(right)
	right.set_anchor_and_offset(SIDE_LEFT, 1.0, -220)
	right.set_anchor_and_offset(SIDE_RIGHT, 1.0, -14)
	right.set_anchor_and_offset(SIDE_TOP, 0.0, 12)
	var shop_hint := UiTheme.label("I : forge", 14, UiTheme.PARCH, 4)
	shop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(shop_hint)
	_sound = UiTheme.label("", 14, UiTheme.PARCH, 4)
	_sound.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_sound)

	_boss_panel = PanelContainer.new()
	var bs := UiTheme.panel_style(Color(0.1, 0.03, 0.05, 0.85))
	bs.set_content_margin_all(6)
	_boss_panel.add_theme_stylebox_override("panel", bs)
	add_child(_boss_panel)
	_boss_panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -190)
	_boss_panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 190)
	_boss_panel.set_anchor_and_offset(SIDE_TOP, 0.0, 10)
	var bbox := VBoxContainer.new()
	_boss_panel.add_child(bbox)
	_boss_name = UiTheme.label("", 18, UiTheme.GOLD, 4)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bbox.add_child(_boss_name)
	_boss_bar = UiTheme.bar(Color("#8e2bd6"), Vector2(360, 12))
	bbox.add_child(_boss_bar)

	_banner = UiTheme.label("", 30, Color("#ffd23c"), 8)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)
	_banner.set_anchor_and_offset(SIDE_LEFT, 0.0, 0)
	_banner.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0)
	_banner.set_anchor_and_offset(SIDE_TOP, 0.0, 100)

	UiTheme.ignore_mouse(self)

func _process(_delta: float) -> void:
	if not visible or world == null:
		return
	var p := world.player
	_hp_bar.max_value = p.max_hp
	_hp_bar.value = p.hp
	_hp_label.text = "%d / %d PV" % [roundi(p.hp), roundi(p.max_hp)]
	_gold.text = str(Save.gold)
	var tag := ""
	if Data.is_final_boss_wave(Game.element, Game.wave):
		tag = " — " + Data.FINAL_BOSS_NAME
	elif Data.is_boss_wave(Game.wave):
		tag = " — " + Data.BOSS_NAMES[Game.element]
	_wave.text = "Vague %d%s" % [Game.wave, tag]
	_mode.text = "%s — %s" % [Game.diff()["label"], Game.elem()["label"]]
	_sound.text = "M : son (coupé)" if Save.muted else "M : son (activé)"

	var boss := world.current_boss()
	_boss_panel.visible = boss != null
	if boss:
		_boss_name.text = Data.FINAL_BOSS_NAME if boss.is_final else Data.BOSS_NAMES[boss.element]
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = maxf(0.0, boss.hp)

	_banner.visible = world.wave_intermission > 0 and world.enemies.is_empty()
	_banner.text = "Vague %d arrive…" % Game.wave
