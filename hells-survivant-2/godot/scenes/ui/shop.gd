class_name Shop
extends Control
## Forge infernale : épée et armure, achats conservés entre les parties.

signal closed

var world: World

var _gold: Label
var _cards: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := UiTheme.label("Forge infernale", 34, UiTheme.EMBER, 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_gold = UiTheme.label("", 15, UiTheme.MUTED)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_gold)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 20)
	box.add_child(_cards)
	var close_row := CenterContainer.new()
	box.add_child(close_row)
	var close := UiTheme.button("Fermer", Vector2(160, 40))
	close.pressed.connect(func() -> void:
		Audio.sfx("click")
		closed.emit())
	close_row.add_child(close)
	refresh()

func refresh() -> void:
	if _cards == null:
		return
	_gold.text = "Or disponible : %d — I ou Échap pour fermer" % Save.gold
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_cards.add_child(_card(true))
	_cards.add_child(_card(false))

func _card(is_sword: bool) -> PanelContainer:
	var tier := Save.sword_tier if is_sword else Save.armor_tier
	var table: Array = Data.SWORDS if is_sword else Data.ARMORS
	var current: Dictionary = table[tier]
	var next: Dictionary = table[tier + 1] if tier + 1 < table.size() else {}

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	var cs := UiTheme.panel_style(Color(0.18, 0.07, 0.05, 0.95))
	cs.border_color = UiTheme.GOLD_DARK
	cs.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", cs)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var icon := TextureRect.new()
	var shown := mini(tier + 1, table.size() - 1)
	var path := "res://assets/sprites/player/%s_%d.png" % ["sword" if is_sword else "body", shown]
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var info := VBoxContainer.new()
	head.add_child(info)
	info.add_child(UiTheme.label("Épée" if is_sword else "Armure", 22, UiTheme.GOLD, 3))
	info.add_child(UiTheme.label("Actuel : %s" % current["name"], 15))
	var stats := "Dégâts : %d" % current["dmg"] if is_sword else \
		"PV : %d   Défense : %d%%" % [current["hp"], roundi(float(current["def"]) * 100.0)]
	info.add_child(UiTheme.label(stats, 15, UiTheme.MUTED))

	if next.is_empty():
		var maxed := UiTheme.label("Niveau maximum atteint", 15, Color("#8a6a4a"))
		maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		maxed.custom_minimum_size = Vector2(0, 40)
		maxed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(maxed)
	else:
		var stat := "Dégâts %d" % next["dmg"] if is_sword else \
			"PV %d · Déf %d%%" % [next["hp"], roundi(float(next["def"]) * 100.0)]
		var buy := UiTheme.button("Acheter %s (%s) — %d or" % [next["name"], stat, next["cost"]], Vector2(0, 40), 14)
		buy.disabled = Save.gold < int(next["cost"])
		buy.pressed.connect(_buy.bind(is_sword))
		box.add_child(buy)
	return card

func _buy(is_sword: bool) -> void:
	if is_sword:
		var next := Save.sword_tier + 1
		if next >= Data.SWORDS.size() or Save.gold < int(Data.SWORDS[next]["cost"]):
			return
		Save.gold -= int(Data.SWORDS[next]["cost"])
		Save.sword_tier = next
	else:
		var next := Save.armor_tier + 1
		if next >= Data.ARMORS.size() or Save.gold < int(Data.ARMORS[next]["cost"]):
			return
		Save.gold -= int(Data.ARMORS[next]["cost"])
		Save.armor_tier = next
		var gain: float = Data.ARMORS[next]["hp"] - Data.ARMORS[next - 1]["hp"]
		world.player.max_hp += gain
		world.player.hp += gain
	Save.write()
	Audio.sfx("purchase")
	world.player.refresh_equipment()
	refresh()
