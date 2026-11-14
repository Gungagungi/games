class_name TouchControls
extends Control
## Commandes tactiles pour jouer sur téléphone, affichées seulement en partie et
## sur écran tactile (`Game.touch_mode`).
##
## - moitié gauche : joystick flottant, qui naît sous le pouce ; sa direction
##   passe à `World` par `Game.touch_dir`, comme les flèches du clavier ;
## - moitié droite : frapper, en continu tant que le doigt reste posé (le
##   rechargement de l'épée fixe la cadence), dans la direction du héros ;
## - en haut à droite : Forge, Menu, Son (touches I, P et M).
##
## Les touchers sont lus directement (`InputEventScreenTouch`, un index par
## doigt) : on peut marcher et frapper en même temps. Godot imite aussi la
## souris avec le premier doigt, ce qui suffit aux boutons du menu et de la
## forge ; en partie, `main.gd` ignore ce clic imité.

signal shop_requested
signal menu_requested
signal mute_requested

var world: World

const STICK_RADIUS := 64.0
const KNOB_RADIUS := 28.0
const DEAD_ZONE := 0.25
const STICK_IDLE := Vector2(120, 480)
const ATTACK_CENTER := Vector2(790, 490)
const ATTACK_RADIUS := 54.0
const BUTTON_RADIUS := 25.0
const BUTTON_Y := 40.0
const BUTTONS := [
	{"id": "shop", "label": "Forge", "x": 720.0},
	{"id": "menu", "label": "Menu", "x": 785.0},
	{"id": "mute", "label": "Son", "x": 850.0},
]

var _stick_finger := -1
var _stick_base := STICK_IDLE
var _stick_knob := STICK_IDLE
var _attack_fingers := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	Game.touch_mode = DisplayServer.is_touchscreen_available()

func _active() -> bool:
	return Game.touch_mode and Game.state == "playing"

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		Game.touch_mode = true
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _active():
				_press(t.index, t.position)
		else:
			_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_move_stick(d.position)

func _press(finger: int, pos: Vector2) -> void:
	for b: Dictionary in BUTTONS:
		if pos.distance_to(Vector2(b["x"], BUTTON_Y)) <= BUTTON_RADIUS + 8:
			_tap_button(b["id"])
			return
	if pos.x < size.x * 0.5:
		if _stick_finger == -1:
			_stick_finger = finger
			# Base gardée entière à l'écran, même pour un pouce collé au bord.
			_stick_base = pos.clamp(Vector2.ONE * STICK_RADIUS, size - Vector2.ONE * STICK_RADIUS)
			_move_stick(pos)
	else:
		_attack_fingers[finger] = true

func _release(finger: int) -> void:
	if finger == _stick_finger:
		_reset_stick()
	_attack_fingers.erase(finger)

func _reset_stick() -> void:
	_stick_finger = -1
	_stick_base = STICK_IDLE
	_stick_knob = STICK_IDLE
	Game.touch_dir = Vector2.ZERO

func _move_stick(pos: Vector2) -> void:
	var off := (pos - _stick_base).limit_length(STICK_RADIUS)
	_stick_knob = _stick_base + off
	var v := off / STICK_RADIUS
	Game.touch_dir = v if v.length() >= DEAD_ZONE else Vector2.ZERO

func _tap_button(id: String) -> void:
	Audio.sfx("click")
	_reset_stick()
	_attack_fingers.clear()
	match id:
		"shop":
			shop_requested.emit()
		"menu":
			menu_requested.emit()
		"mute":
			mute_requested.emit()

func _process(_delta: float) -> void:
	if not _active():
		if _stick_finger != -1 or not _attack_fingers.is_empty():
			_reset_stick()
			_attack_fingers.clear()
	elif not _attack_fingers.is_empty() and world != null:
		world.do_attack()
	queue_redraw()

func _draw() -> void:
	if not Game.touch_mode:
		return
	if _portrait():
		_draw_rotate_hint()
		return
	if Game.state != "playing":
		return
	var font := get_theme_default_font()
	# Joystick : discret au repos, plus net sous le pouce.
	var held := _stick_finger != -1
	draw_circle(_stick_base, STICK_RADIUS, Color(0, 0, 0, 0.35 if held else 0.18))
	draw_arc(_stick_base, STICK_RADIUS, 0, TAU, 48, Color(1, 0.85, 0.6, 0.6 if held else 0.3), 3)
	draw_circle(_stick_knob, KNOB_RADIUS, Color(1, 0.8, 0.45, 0.55 if held else 0.25))
	# Frapper.
	var hit := not _attack_fingers.is_empty()
	draw_circle(ATTACK_CENTER, ATTACK_RADIUS, Color(0.6, 0.1, 0.05, 0.6 if hit else 0.32))
	draw_arc(ATTACK_CENTER, ATTACK_RADIUS, 0, TAU, 48, Color(1, 0.8, 0.4, 0.8 if hit else 0.45), 3)
	_draw_label(font, "Frapper", ATTACK_CENTER, 18)
	for b: Dictionary in BUTTONS:
		var c := Vector2(b["x"], BUTTON_Y)
		draw_circle(c, BUTTON_RADIUS, Color(0.1, 0.04, 0.03, 0.75))
		draw_arc(c, BUTTON_RADIUS, 0, TAU, 32, UiTheme.GOLD, 2)
		var text: String = b["label"]
		if b["id"] == "mute" and Save.muted:
			text = "Muet"
		_draw_label(font, text, c, 13)

func _draw_label(font: Font, text: String, center: Vector2, font_size: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := center + Vector2(-w / 2, font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

## Le jeu garde son format 3:2 : en portrait, il tiendrait dans une bande
## minuscule au milieu de l'écran.
func _portrait() -> bool:
	var s := get_window().size
	return s.y > s.x

func _draw_rotate_hint() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.0, 0.0, 0.9))
	_draw_label(font, "Tourne ton téléphone", size / 2 - Vector2(0, 30), 56)
	_draw_label(font, "le jeu se joue en paysage", size / 2 + Vector2(0, 40), 36)
