class_name FloatText
extends Node2D
## Chiffre de dégâts qui monte et s'efface.

var text := ""
var color := Color.WHITE
var _t := 0.0
const LIFETIME := 0.7

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_font_size_override("font_size", 15)
	_label.position = Vector2(-20, -10)
	_label.size = Vector2(40, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

func _process(delta: float) -> void:
	_t += delta
	position.y -= 40.0 * delta
	modulate.a = 1.0 - _t / LIFETIME
	if _t >= LIFETIME:
		queue_free()
