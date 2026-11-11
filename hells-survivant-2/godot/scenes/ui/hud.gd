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
	# Centrée par un conteneur pleine largeur : des ancres à 0,5 + offsets
	# laissaient la barre étirée et collée à gauche (offsets recalculés contre
	# un parent pas encore dimensionné).
	var boss_row := CenterContainer.new()
	add_child(boss_row)
	boss_row.anchor_left = 0.0
	boss_row.anchor_right = 1.0
	boss_row.anchor_top = 0.0
	boss_row.anchor_bottom = 0.0
	boss_row.offset_left = 0
	boss_row.offset_right = 0
	boss_row.offset_top = 10
	boss_row.offset_bottom = 10
	boss_row.add_child(_boss_panel)
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
	var boss_name := world.wave_boss_name()
	var tag := " — " + boss_name if boss_name != "" else ""
	_wave.text = "Vague %d%s" % [Game.wave, tag]
	_mode.text = "%s — %s" % [Game.diff()["label"], Game.elem()["label"]]
	_sound.text = "M : son (coupé)" if Save.muted else "M : son (activé)"
	if Game.boss_rush:
		_process_boss_rush()
		return

	var boss := world.current_boss()
	_boss_panel.visible = boss != null
	if boss:
		_boss_name.text = World.boss_name(boss)
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = maxf(0.0, boss.hp)

	_banner.visible = world.wave_intermission > 0 and world.enemies.is_empty()
	_banner.text = "Vague %d arrive…" % Game.wave

## Conclave : boss restants, temps écoulé et une barre pour la vie cumulée de
## tous les boss (chacun a aussi la sienne au-dessus de sa tête).
func _process_boss_rush() -> void:
	var alive := 0
	var hp := 0.0
	for e in world.enemies:
		if e.is_boss:
			alive += 1
			hp += maxf(0.0, e.hp)
	var secs := world.rush_ticks / 60
	_wave.text = "Boss restants : %d / %d" % [alive, world.rush_total]
	_mode.text = "%s — %d:%02d" % [Game.diff()["label"], secs / 60, secs % 60]
	_boss_panel.visible = true
	_boss_name.text = Data.BOSS_RUSH["name"]
	_boss_bar.max_value = maxf(1.0, world.rush_max_hp)
	_boss_bar.value = hp
	_banner.visible = world.rush_intro > 0
	_banner.text = "Le conclave des boss s'assemble…"
