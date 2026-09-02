class_name DialogueBox
extends CanvasLayer
## Réplique pausée : coupe `GameState.running` (donc joueur, ennemis et
## vagues, tous gardés par ce flag) le temps du texte, et le relâche au clic
## ou à une touche. En smoke test, la réplique passe instantanément — sinon
## `check.sh` resterait bloqué en attente d'une entrée qui ne viendra jamais.

var _speaker := Label.new()
var _text := Label.new()

func _ready() -> void:
	layer = 25
	visible = false
	EventBus.dialogue_requested.connect(_show)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, 60)
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	box.add_child(_speaker)

	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_text)

	var hint := Label.new()
	hint.text = "— clic pour continuer —"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1.0, 1.0, 1.0, 0.55)
	box.add_child(hint)

func _show(speaker: String, text: String) -> void:
	if GameState.smoke_test:
		EventBus.dialogue_finished.emit()
		return
	_speaker.text = speaker
	_text.text = text
	visible = true
	GameState.running = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if not pressed:
		return
	visible = false
	GameState.running = true
	get_viewport().set_input_as_handled()
	AudioManager.sfx("ui_click")
	EventBus.dialogue_finished.emit()
