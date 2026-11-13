class_name TouchControls
extends CanvasLayer
## Commandes tactiles (mobile, Safari iOS compris) : un joystick en bas à
## gauche pour bouger, un gros bouton en bas à droite pour tirer, et deux petits
## boutons à côté pour le dash et l'onde de choc.
##
## Tout passe par les actions de `project.godot` (`Input.action_press`), si bien
## que `Player` ne sait pas d'où vient un déplacement ou un dash — à une
## exception près, le tir : le navigateur convertit chaque toucher en clic
## gauche (émulation souris de Godot, nécessaire aux boutons des menus), et ce
## clic est lié à `shoot`. Le pouce posé sur le joystick ferait donc tirer. En
## mode tactile, `Player` lit `GameState.touch_fire` au lieu de l'action, et vise
## seul l'ennemi le plus proche puisqu'il n'y a pas de pointeur.
##
## Le mode tactile s'allume au premier toucher (ou d'emblée si l'appareil a un
## écran tactile) et s'éteint à la première touche de clavier.

const JOY_RADIUS := 70.0
const KNOB_RADIUS := 30.0
const FIRE_RADIUS := 62.0
const SKILL_RADIUS := 36.0
## Marge latérale : laisse de la place à l'encoche d'un iPhone en paysage.
const SIDE_MARGIN := 48.0
const BOTTOM_MARGIN := 40.0
## Les petits boutons sont un peu plus larges au toucher qu'à l'œil.
const HIT_SLACK := 1.25

## `id` = compétence côté `SkillBar` ; `action` = action pressée ; `offset`
## depuis le centre du bouton de tir.
const SKILLS := [
	{"id": "dash", "action": "dash", "label": "DASH", "offset": Vector2(-118.0, 36.0)},
	{"id": "shockwave", "action": "shockwave", "label": "ONDE", "offset": Vector2(-62.0, -104.0)},
]

var player: Player
## Écrans qui recouvrent la partie (choix de pouvoir, fin) : le jeu tourne
## encore derrière, mais un doigt posé sur une carte ne doit pas faire bouger
## le mech.
var menus: Array[CanvasLayer] = []

var _canvas := Control.new()
var _icons: Array[AtlasTexture] = []
## Doigt de chaque commande (-1 = libre) : le jeu est multitouch, on bouge et
## on tire en même temps.
var _joy_finger := -1
var _fire_finger := -1
var _skill_fingers: Array[int] = []
var _joy_center := Vector2.ZERO
var _joy_vector := Vector2.ZERO
var _active := false

func _ready() -> void:
	layer = 15 # au-dessus du HUD, sous les écrans de menu
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	for skill in SKILLS:
		_skill_fingers.append(-1)
		_icons.append(SkillBar.icon_for(str(SkillBar.icon_id(str(skill["id"])))))
	if DisplayServer.is_touchscreen_available() and not GameState.smoke_test:
		GameState.touch_mode = true

func _process(_delta: float) -> void:
	var active := GameState.touch_mode and GameState.running \
		and player != null and player.alive \
		and not menus.any(func(m: CanvasLayer) -> bool: return m.visible)
	if active != _active:
		_active = active
		if not active:
			_release_all()
	visible = active
	if active:
		_canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		GameState.touch_mode = false
		return
	if event is InputEventScreenTouch:
		GameState.touch_mode = true
		if not _active:
			return
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
	elif event is InputEventScreenDrag and _active:
		var drag := event as InputEventScreenDrag
		if drag.index == _joy_finger:
			_steer(drag.position)

func _on_press(finger: int, pos: Vector2) -> void:
	var view := _view_size()
	# Les petits boutons d'abord : ils sont posés dans la zone de tir.
	for i in SKILLS.size():
		var skill: Dictionary = SKILLS[i]
		if not SkillBar.available(player, str(skill["id"])):
			continue
		if pos.distance_to(_skill_center(i)) <= SKILL_RADIUS * HIT_SLACK:
			_skill_fingers[i] = finger
			Input.action_press(str(skill["action"]))
			return
	if pos.x < view.x * 0.45:
		if _joy_finger == -1:
			# Joystick flottant : il se recentre sous le pouce, où qu'il se pose
			# dans la moitié gauche — on ne vise pas un cercle à l'aveugle.
			_joy_finger = finger
			_joy_center = pos
			_steer(pos)
	elif pos.x > view.x * 0.5:
		# Toute la moitié droite tire : le bouton dessiné n'est qu'un repère.
		if _fire_finger == -1:
			_fire_finger = finger
			GameState.touch_fire = true

func _on_release(finger: int) -> void:
	if finger == _joy_finger:
		_joy_finger = -1
		_steer_to(Vector2.ZERO)
	if finger == _fire_finger:
		_fire_finger = -1
		GameState.touch_fire = false
	for i in SKILLS.size():
		if _skill_fingers[i] == finger:
			_skill_fingers[i] = -1
			Input.action_release(str(SKILLS[i]["action"]))

func _steer(pos: Vector2) -> void:
	_steer_to((pos - _joy_center).limit_length(JOY_RADIUS) / JOY_RADIUS)

## `get_vector()` lit la force de chaque action : un pouce à mi-course fait
## avancer le mech à mi-vitesse.
func _steer_to(v: Vector2) -> void:
	_joy_vector = v
	_press_axis("move_left", "move_right", v.x)
	_press_axis("move_up", "move_down", v.y)

func _press_axis(negative: String, positive: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)

func _release_all() -> void:
	_joy_finger = -1
	_fire_finger = -1
	GameState.touch_fire = false
	_steer_to(Vector2.ZERO)
	for i in SKILLS.size():
		_skill_fingers[i] = -1
		Input.action_release(str(SKILLS[i]["action"]))

func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _joy_rest() -> Vector2:
	var view := _view_size()
	return Vector2(SIDE_MARGIN + JOY_RADIUS, view.y - BOTTOM_MARGIN - JOY_RADIUS)

func _fire_center() -> Vector2:
	var view := _view_size()
	return Vector2(view.x - SIDE_MARGIN - FIRE_RADIUS, view.y - BOTTOM_MARGIN - FIRE_RADIUS)

func _skill_center(i: int) -> Vector2:
	return _fire_center() + (SKILLS[i]["offset"] as Vector2)

func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	if _canvas.get_theme_default_font() != null:
		font = _canvas.get_theme_default_font()
	# Joystick : au repos en bas à gauche, sous le pouce quand il est tenu.
	var base := _joy_center if _joy_finger != -1 else _joy_rest()
	_canvas.draw_circle(base, JOY_RADIUS, Color(0.08, 0.1, 0.14, 0.45))
	_canvas.draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, Color(0.85, 0.72, 0.35, 0.6), 2.0)
	_canvas.draw_circle(base + _joy_vector * JOY_RADIUS, KNOB_RADIUS,
		Color(0.85, 0.72, 0.35, 0.75 if _joy_finger != -1 else 0.45))

	var fire := _fire_center()
	_canvas.draw_circle(fire, FIRE_RADIUS,
		Color(0.85, 0.25, 0.3, 0.7 if _fire_finger != -1 else 0.42))
	_canvas.draw_arc(fire, FIRE_RADIUS, 0.0, TAU, 48, Color(1.0, 0.8, 0.7, 0.7), 2.0)
	_label(font, fire, "TIR", 20)

	for i in SKILLS.size():
		var skill: Dictionary = SKILLS[i]
		var id := str(skill["id"])
		if not SkillBar.available(player, id):
			continue
		var c := _skill_center(i)
		var ready_now := SkillBar.ready_to_use(player, id)
		var held := _skill_fingers[i] != -1
		_canvas.draw_circle(c, SKILL_RADIUS, Color(0.08, 0.1, 0.14, 0.75 if held else 0.55))
		if _icons[i] != null:
			var s := SKILL_RADIUS * 1.1
			_canvas.draw_texture_rect(_icons[i], Rect2(c - Vector2(s, s) * 0.5 - Vector2(0, 6), Vector2(s, s)), false)
		# Recharge : un secteur sombre qui se referme dans le sens horaire.
		var cd := clampf(SkillBar.cooldown_ratio(player, id), 0.0, 1.0)
		if cd > 0.0:
			_pie(c, SKILL_RADIUS, cd, Color(0.02, 0.03, 0.05, 0.7))
		elif not ready_now:
			_canvas.draw_circle(c, SKILL_RADIUS, Color(0.02, 0.03, 0.05, 0.45))
		var border := Color(0.85, 0.72, 0.35) if ready_now else Color(0.3, 0.34, 0.42)
		_canvas.draw_arc(c, SKILL_RADIUS, 0.0, TAU, 40, border, 2.0)
		_label(font, c + Vector2(0, SKILL_RADIUS * 0.55), str(skill["label"]), 12)

func _pie(center: Vector2, radius: float, ratio: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	var steps := maxi(3, int(40 * ratio))
	for k in steps + 1:
		var a := -PI * 0.5 + TAU * ratio * float(k) / float(steps)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	_canvas.draw_colored_polygon(points, color)

func _label(font: Font, center: Vector2, text: String, size: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-w * 0.5, size * 0.35)
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4,
		Color(0.02, 0.03, 0.05, 0.9))
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.9))
