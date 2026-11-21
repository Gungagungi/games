class_name UpgradeScreen
extends CanvasLayer
## Trois pouvoirs tirés au sort entre deux vagues, en trois cartes (v2 :
## `upgrade_screen.gd`). Clic, toucher, ou touches 1 / 2 / 3. Les icônes
## viennent de `ui_upgrades.png`, copiée de la v2.

signal upgrade_chosen(id: String)

const ICON_SIZE := 32
const ICON_DISPLAY := 88
const CARD := Vector2(250, 236)

var _root := VBoxContainer.new()
var _grid := HBoxContainer.new()
var _ids: Array[String] = []
var _icons: Texture2D

func _ready() -> void:
	layer = 20
	visible = false
	if ResourceLoader.exists("res://assets/ui/ui_upgrades.png"):
		_icons = load("res://assets/ui/ui_upgrades.png")
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_root.add_theme_constant_override("separation", 18)
	center.add_child(_root)
	var title := Label.new()
	title.text = "CHOISIS UN POUVOIR"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	_grid.add_theme_constant_override("separation", 16)
	_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_grid)
	var hint := Label.new()
	hint.text = "Clic ou touches 1 · 2 · 3"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.6
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(hint)

func present(choices: Array[Dictionary]) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_ids.clear()
	# Écrans étroits (téléphone en portrait) : des cartes plus petites.
	var vp := get_viewport().get_visible_rect().size
	var card := CARD
	if vp.x < CARD.x * 3 + 80:
		card = Vector2((vp.x - 80) / 3.0, CARD.y)
	for up in choices:
		_ids.append(str(up["id"]))
		_grid.add_child(_card(up, card))
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n < 0 or n >= _ids.size():
			n = event.physical_keycode - KEY_KP_1
		if n >= 0 and n < _ids.size():
			get_viewport().set_input_as_handled()
			_choose(_ids[n])

func _choose(id: String) -> void:
	AudioManager.sfx("upgrade_pick")
	visible = false
	upgrade_chosen.emit(id)

## Une carte = un bouton garni d'une colonne icône / nom / description ; les
## enfants laissent passer la souris, sinon ils mangeraient le clic.
func _card(up: Dictionary, size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 14
	box.offset_bottom = -14
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	b.add_child(box)
	if _icons != null:
		var icon := AtlasTexture.new()
		icon.atlas = _icons
		icon.region = Rect2(UpgradeManager.index_of(str(up["id"])) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(ICON_DISPLAY, ICON_DISPLAY)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex)
	var name_label := Label.new()
	name_label.text = "%d · %s" % [_ids.size(), str(up["name"])]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var desc := Label.new()
	desc.text = str(up["desc"])
	desc.add_theme_font_size_override("font_size", 15)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc)
	var id: String = up["id"]
	b.pressed.connect(_choose.bind(id))
	return b
