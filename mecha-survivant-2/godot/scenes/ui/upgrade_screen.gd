class_name UpgradeScreen
extends CanvasLayer
## Trois pouvoirs tirés au sort entre deux vagues.
##
## Chaque bouton porte l'icône du pouvoir, découpée dans `ui_upgrades.png` : la
## case d'un pouvoir est son rang dans `UpgradeManager.ALL`, l'ordre du manifeste.
## Sans la planche, les boutons restent purement textuels.

signal upgrade_chosen(id: String)

const ICON_SHEET := "ui_upgrades"
const ICON_SIZE := 32

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
		var icon := _icon_for(str(up["id"]))
		if icon != null:
			b.icon = icon
			b.expand_icon = false
		var id: String = up["id"]
		b.pressed.connect(func() -> void:
			AudioManager.sfx("upgrade_pick")
			visible = false
			upgrade_chosen.emit(id))
		_list.add_child(b)
	visible = true

## Icône d'un pouvoir, ou `null` tant que `ui_upgrades.png` n'est pas déposé.
func _icon_for(id: String) -> AtlasTexture:
	var sheet := SpriteOrShape.sheet_texture(ICON_SHEET)
	if sheet == null:
		return null
	var index := 0
	for i in UpgradeManager.ALL.size():
		if UpgradeManager.ALL[i]["id"] == id:
			index = i
			break
	var icon := AtlasTexture.new()
	icon.atlas = sheet
	icon.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	return icon
