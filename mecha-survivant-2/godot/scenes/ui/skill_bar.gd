class_name SkillBar
extends Control
## Barre des compétences actives, en bas à gauche : icône, touche et temps de
## recharge restant.
##
## La barre lit l'état du joueur à chaque frame plutôt que d'écouter des
## signaux : un compte à rebours n'émet rien, il s'affiche en continu. Une
## compétence non débloquée (l'onde de choc avant le pouvoir « aoe ») n'occupe
## pas de case — la barre grandit quand le mech grandit.
##
## Les icônes viennent de `ui_upgrades.png`, par le rang du pouvoir dans
## `UpgradeManager.ALL` : l'onde de choc a la sienne, le dash emprunte celle des
## propulseurs (`speed`), faute de case dédiée dans la planche.

const SLOT := 64.0
const GAP := 10.0
const MARGIN := Vector2(20.0, -16.0) ## depuis le coin bas-gauche de l'écran
const ICON_SHEET := "ui_upgrades"
const ICON_SIZE := 32

## `icon` = id de pouvoir dont la case sert d'icône ; `key` = touche affichée.
const SKILLS := [
	{"id": "dash", "icon": "speed", "key": "MAJ", "label": "Dash"},
	{"id": "shockwave", "icon": "aoe", "key": "F", "label": "Onde"},
]

var player: Player

var _slots: Array[Control] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = MARGIN.x
	offset_top = MARGIN.y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for skill in SKILLS:
		var slot := _make_slot(skill)
		add_child(slot)
		_slots.append(slot)

func _process(_delta: float) -> void:
	if player == null:
		return
	var x := 0.0
	for i in _slots.size():
		var slot := _slots[i]
		var skill: Dictionary = SKILLS[i]
		slot.visible = _available(str(skill["id"]))
		if not slot.visible:
			continue
		slot.position = Vector2(x, -SLOT)
		x += SLOT + GAP
		var id := str(skill["id"])
		slot.set_meta("cooldown", _cooldown(id))
		slot.set_meta("ready", _ready_to_use(id))
		(slot.get_node("Overlay") as Control).queue_redraw()
		var left := _seconds_left(id)
		var timer := slot.get_node("Timer") as Label
		timer.text = "" if left <= 0.0 else ("%.1f" % left)

## Une compétence toujours disponible (le dash) contre une compétence à
## débloquer (l'onde de choc).
func _available(id: String) -> bool:
	return id != "shockwave" or player.aoe_unlocked

## Part de recharge restante, de 1 (à peine lancée) à 0 (prête).
func _cooldown(id: String) -> float:
	if id == "dash":
		return player.dash_cd / Player.DASH_COOLDOWN
	return player.aoe_cd / Player.AOE_COOLDOWN

## Le dash coûte de l'endurance : recharge finie ne veut pas dire utilisable.
func _ready_to_use(id: String) -> bool:
	if id == "dash":
		return player.dash_cd <= 0.0 and player.stamina >= Player.DASH_COST
	return player.aoe_cd <= 0.0

func _make_slot(skill: Dictionary) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("cooldown", 0.0)
	slot.set_meta("ready", true)
	slot.draw.connect(_draw_background.bind(slot))

	var icon := _icon_for(str(skill["icon"]))
	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.position = Vector2(8, 4)
		tex.size = Vector2(SLOT - 16, SLOT - 24)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.size = Vector2(SLOT, SLOT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay.bind(overlay, slot))
	slot.add_child(overlay)

	var timer := Label.new()
	timer.name = "Timer"
	timer.add_theme_font_size_override("font_size", 18)
	timer.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05))
	timer.add_theme_constant_override("outline_size", 6)
	timer.size = Vector2(SLOT, 22)
	timer.position = Vector2(0, SLOT * 0.5 - 17)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(timer)

	var key := Label.new()
	key.text = str(skill["key"])
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", Color(0.82, 0.78, 0.66))
	key.position = Vector2(0, SLOT - 19)
	key.size = Vector2(SLOT, 16)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(key)
	return slot

## Le fond se peint avant les enfants (Godot dessine un CanvasItem puis sa
## descendance) ; le voile de recharge et le cadre passent donc par un enfant
## `Overlay` placé après l'icône, sans quoi l'icône les recouvrirait.
func _draw_background(slot: Control) -> void:
	slot.draw_rect(Rect2(Vector2.ZERO, Vector2(SLOT, SLOT)), Color(0.08, 0.1, 0.14, 0.85))

func _draw_overlay(overlay: Control, slot: Control) -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(SLOT, SLOT))
	var ready_now: bool = slot.get_meta("ready")
	var cd: float = clampf(slot.get_meta("cooldown"), 0.0, 1.0)
	if cd > 0.0:
		var h := SLOT * cd
		overlay.draw_rect(Rect2(0.0, SLOT - h, SLOT, h), Color(0.02, 0.03, 0.05, 0.7))
	elif not ready_now:
		overlay.draw_rect(rect, Color(0.02, 0.03, 0.05, 0.45))
	var border := Color(0.85, 0.72, 0.35) if ready_now else Color(0.3, 0.34, 0.42)
	overlay.draw_rect(rect, border, false, 2.0)

## Secondes de recharge restantes, 0 si la compétence est prête.
func _seconds_left(id: String) -> float:
	return player.dash_cd if id == "dash" else player.aoe_cd

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
