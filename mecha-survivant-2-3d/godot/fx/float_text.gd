class_name FloatText
extends Label3D
## Chiffre de dégâts qui monte et s'efface (v2 : `float_text.gd`). Toujours
## tourné vers la caméra, taille fixe à l'écran, visible à travers le décor.

const DURATION := 0.7

var _t := 0.0

func _init(text_value: String, col: Color) -> void:
	text = text_value
	modulate = col
	outline_modulate = Color(0, 0, 0, 0.9)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fixed_size = true
	pixel_size = 0.0011
	font_size = 30
	outline_size = 8
	no_depth_test = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	_t += delta
	position.y += delta * 1.6
	modulate.a = 1.0 - _t / DURATION
	outline_modulate.a = modulate.a
	if _t >= DURATION:
		queue_free()
