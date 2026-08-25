class_name UpgradeScreen
extends CanvasLayer
## Trois pouvoirs tirés au sort entre deux vagues, présentés en trois colonnes.
##
## Chaque carte porte l'icône du pouvoir, découpée dans `ui_upgrades.png` : la
## case d'un pouvoir est son rang dans `UpgradeManager.ALL`, l'ordre du manifeste.
## L'icône de 32 px est agrandie au plus proche voisin (`ICON_DISPLAY`) — c'est
## tout l'intérêt des colonnes. Sans la planche, les cartes restent textuelles.

signal upgrade_chosen(id: String)

const ICON_SHEET := "ui_upgrades"
const ICON_SIZE := 32
const ICON_DISPLAY := 96
const CARD := Vector2(248, 232)
const COLUMNS := 3

var _root := VBoxContainer.new()

func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.position = Vector2(-(CARD.x * COLUMNS + 32) * 0.5, -(CARD.y + 60) * 0.5)
	_root.add_theme_constant_override("separation", 18)
	add_child(_root)

func present(choices: Array[Dictionary]) -> void:
	for child in _root.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "CHOISIS UN POUVOIR"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(CARD.x * COLUMNS + 32, 0)
	_root.add_child(title)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	_root.add_child(grid)
	for up in choices:
		grid.add_child(_card(up))
	visible = true

## Une carte = un bouton de la taille de la colonne, garni d'une colonne
## icône / nom / description. Les enfants laissent passer la souris, sinon ils
## mangeraient le clic destiné au bouton qui les porte.
func _card(up: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 14
	box.offset_bottom = -14
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	b.add_child(box)

	var icon := _icon_for(str(up["id"]))
	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(ICON_DISPLAY, ICON_DISPLAY)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex)

	var name_label := Label.new()
	name_label.text = str(up["name"])
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var desc := Label.new()
	desc.text = str(up["desc"])
	desc.add_theme_font_size_override("font_size", 14)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc)

	var id: String = up["id"]
	b.pressed.connect(func() -> void:
		AudioManager.sfx("upgrade_pick")
		visible = false
		upgrade_chosen.emit(id))
	return b

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
