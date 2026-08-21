class_name UpgradeScreen
extends CanvasLayer
## Trois pouvoirs tirés au sort entre deux vagues.

signal upgrade_chosen(id: String)

var _list := VBoxContainer.new()

func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_list.set_anchors_preset(Control.PRESET_CENTER)
	_list.position = Vector2(-220, -140)
	_list.custom_minimum_size = Vector2(440, 0)
	_list.add_theme_constant_override("separation", 12)
	add_child(_list)

func present(choices: Array[Dictionary]) -> void:
	for child in _list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "CHOISIS UN POUVOIR"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(title)
	for up in choices:
		var b := Button.new()
		b.text = "%s\n%s" % [up["name"], up["desc"]]
		b.custom_minimum_size = Vector2(440, 62)
		var id: String = up["id"]
		b.pressed.connect(func() -> void:
			AudioManager.sfx("upgrade_pick")
			visible = false
			upgrade_chosen.emit(id))
		_list.add_child(b)
	visible = true
