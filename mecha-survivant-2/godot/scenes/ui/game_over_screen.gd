class_name GameOverScreen
extends CanvasLayer
## Fin de partie — défaite, victoire après le Boss Galaxie, ou gemme dorée
## ramassée sur le Destructeur d'univers (le jeu est alors réussi), puis fin
## d'un combat d'entraînement contre le Cristal.
##
## Le Cristal se lance depuis l'écran-titre, une fois débloqué par la gemme ;
## ici, le bouton « RECOMBATTRE » n'apparaît qu'à l'issue d'un combat contre
## lui. Le bouton principal ramène à l'écran-titre (« REJOUER », ou « QUITTER
## L'ARÈNE » depuis l'entraînement).

signal restart_requested()
signal crystal_requested()

var _title := Label.new()
var _detail := Label.new()
var _crystal := Button.new()
var _again := Button.new()

func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-200, -90)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	_title.add_theme_font_size_override("font_size", 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail)
	_crystal.pressed.connect(func() -> void:
		AudioManager.sfx("ui_click")
		visible = false
		crystal_requested.emit())
	box.add_child(_crystal)
	_again.pressed.connect(func() -> void:
		AudioManager.sfx("ui_click")
		visible = false
		restart_requested.emit())
	box.add_child(_again)

## `crystal_label` vide : pas de bouton du Cristal.
func _set_buttons(crystal_label: String, again_label: String) -> void:
	_crystal.text = crystal_label
	_crystal.visible = crystal_label != ""
	_again.text = again_label

func show_result(victory: bool, wave: int) -> void:
	if victory:
		_title.text = "ROBOT GÉANT MUTANT VAINCU"
		_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
		_detail.text = "Les %d vagues sont tombées.\nSon patron, le Destructeur d'univers, t'attend dans le niveau spécial." % GameState.FINAL_WAVE
		_set_buttons("", "REJOUER")
	else:
		_title.text = "MECH DÉTRUIT"
		_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		if GameState.crystal_training:
			_detail.text = "Le cristal l'emporte. Bouge davantage entre ses rayons."
			_set_buttons("RECOMBATTRE", "QUITTER L'ARÈNE")
		else:
			_detail.text = "Le Destructeur d'univers l'emporte." if GameState.special_level \
				else "Vague atteinte : %d" % wave
			_set_buttons("", "REJOUER")
	visible = true

func show_golden_gem() -> void:
	_title.text = "JEU RÉUSSI"
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))
	_detail.text = "Le Destructeur d'univers est tombé.\nLa gemme dorée est à toi.\n\nCristal débloqué : affronte-le depuis le menu principal, autant de fois que tu veux."
	_set_buttons("", "MENU PRINCIPAL")
	visible = true

func show_crystal_destroyed() -> void:
	_title.text = "Bravo, tu as détruit le cristal !"
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))
	_detail.text = "Recommence pour t'entraîner, ou quitte l'arène."
	_set_buttons("RECOMBATTRE", "QUITTER L'ARÈNE")
	visible = true
