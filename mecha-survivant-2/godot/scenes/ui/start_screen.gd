class_name StartScreen
extends CanvasLayer
## Écran d'accueil : titre, sélecteur de vague de départ (1-20) et accès au
## niveau spécial du Destructeur d'univers.
##
## Le bouton du niveau spécial est **sous** LANCER : ajouté au-dessus, il
## décalerait les coordonnées de clic de `tools/scenarios/ms2-gameplay.js`.

signal start_requested(wave: int)
signal destroyer_requested()

var _wave_select := OptionButton.new()

func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	panel.position = Vector2(-220, -170)
	panel.custom_minimum_size = Vector2(440, 0)
	add_child(panel)

	var title := Label.new()
	title.text = "MECHA SURVIVANT 2"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var help := Label.new()
	help.text = "ZQSD / flèches : bouger — souris ou espace : tirer\nMaj : dash — F : onde de choc"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(help)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	panel.add_child(spacer)

	for i in GameState.FINAL_WAVE:
		_wave_select.add_item("Vague %d" % (i + 1), i + 1)
	_wave_select.selected = 0
	panel.add_child(_wave_select)

	var play := Button.new()
	play.text = "LANCER"
	play.custom_minimum_size = Vector2(0, 46)
	play.pressed.connect(func() -> void:
		AudioManager.sfx("ui_click")
		start_requested.emit(_wave_select.get_item_id(_wave_select.selected)))
	panel.add_child(play)

	var destroyer := Button.new()
	destroyer.text = "NIVEAU SPÉCIAL : LE DESTRUCTEUR D'UNIVERS"
	destroyer.custom_minimum_size = Vector2(0, 46)
	destroyer.add_theme_color_override("font_color", Color(1.0, 0.86, 0.12))
	destroyer.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6))
	destroyer.pressed.connect(func() -> void:
		AudioManager.sfx("ui_click")
		destroyer_requested.emit())
	panel.add_child(destroyer)

	var version := Label.new()
	version.text = GameVersion.read()
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.4))
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(12, -28)
	add_child(version)
