class_name UiTheme
extends RefCounted
## Habillage de l'interface : cadres sombres bordés d'or, dans l'esprit HoMM2.

const GOLD := Color("#d9a441")
const GOLD_DARK := Color("#7a5520")
const PARCH := Color("#f2dfb4")
const MUTED := Color("#b58a80")
const EMBER := Color("#ff5a3c")

static func panel_style(bg := Color(0.13, 0.06, 0.04, 0.94)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = GOLD
	s.set_border_width_all(3)
	s.set_corner_radius_all(3)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 6
	s.set_content_margin_all(14)
	return s

static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

static func flat(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("normal", "Button", button_style(Color(0.24, 0.09, 0.06), GOLD_DARK))
	t.set_stylebox("hover", "Button", button_style(Color(0.36, 0.13, 0.08), GOLD))
	t.set_stylebox("pressed", "Button", button_style(Color(0.55, 0.16, 0.1), Color("#ffd23c")))
	t.set_stylebox("hover_pressed", "Button", button_style(Color(0.6, 0.2, 0.12), Color("#ffd23c")))
	t.set_stylebox("disabled", "Button", button_style(Color(0.14, 0.09, 0.08), Color(0.3, 0.22, 0.15)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PARCH)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.42, 0.38))
	t.set_color("font_color", "Label", PARCH)
	t.set_color("font_outline_color", "Label", Color(0.08, 0.0, 0.0))
	return t

static func label(text: String, size := 16, color := PARCH, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
	return l

static func button(text: String, min_size: Vector2, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	# Sans focus : Espace et Entrée restent aux commandes du jeu, pas au dernier bouton cliqué.
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	return b

static func bar(fill: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = min_size
	var bg := button_style(Color(0.04, 0.01, 0.01, 0.9), GOLD_DARK)
	bg.set_content_margin_all(0)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", flat(fill))
	return b

static func ignore_mouse(root: Control) -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in root.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
