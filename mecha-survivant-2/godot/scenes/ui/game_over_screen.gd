class_name GameOverScreen
extends CanvasLayer
## Fin de partie — défaite ou victoire après le Titan.

signal restart_requested()

var _title := Label.new()
var _detail := Label.new()

func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-200, -90)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	_title.add_theme_font_size_override("font_size", 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)
	var again := Button.new()
	again.text = "REJOUER"
	again.pressed.connect(func() -> void:
		AudioManager.sfx("ui_click")
		visible = false
		restart_requested.emit())
	box.add_child(again)

func show_result(victory: bool, wave: int) -> void:
	if victory:
		_title.text = "TITAN TERRASSÉ"
		_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
		_detail.text = "Les 20 vagues sont tombées."
	else:
		_title.text = "MECH DÉTRUIT"
		_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		_detail.text = "Vague atteinte : %d" % wave
	visible = true
