class_name EndScreen
extends Control
## Défaite ou victoire contre le Nécromancien Putréfié.

signal back_requested

var _panel_style: StyleBoxFlat
var _title: Label
var _wave: Label
var _gold: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	_panel_style = UiTheme.panel_style()
	_panel_style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = UiTheme.label("", 36, Color.WHITE, 6)
	_wave = UiTheme.label("", 18)
	_gold = UiTheme.label("", 18, Color("#ffd23c"))
	var hint := UiTheme.label("Clic ou Entrée : retour au menu (équipement conservé)", 14, UiTheme.MUTED)
	for l in [_title, _wave, _gold, hint]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	UiTheme.ignore_mouse(self)
	mouse_filter = MOUSE_FILTER_STOP

func present(victory: bool) -> void:
	if victory:
		_title.text = "%s est tombé" % Data.FINAL_BOSS_NAME
		_title.add_theme_color_override("font_color", Color("#c084fc"))
		_panel_style.border_color = Color("#a855f7")
		_wave.text = "Tu as survécu jusqu'à la vague %d" % Game.wave
	else:
		_title.text = "Tu es tombé aux enfers"
		_title.add_theme_color_override("font_color", Color("#ff3c3c"))
		_panel_style.border_color = UiTheme.GOLD
		_wave.text = "Vague atteinte : %d" % Game.wave
	_gold.text = "Or récolté ce run : %d" % Game.run_gold

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		back_requested.emit()
