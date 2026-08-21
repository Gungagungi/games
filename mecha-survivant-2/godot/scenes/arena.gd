class_name Arena
extends Node2D
## Terrain de jeu : la grille de fond, le joueur, le gestionnaire de vagues et
## tout ce qui est instancié en cours de partie. Le screen shake s'applique ici,
## en décalant l'ensemble.

const GRID_SPACING := 40.0
const GRID_COLOR := Color(0.23, 0.28, 0.38, 0.16)

var player: Player
var waves: WaveManager

var _shake := 0.0
var _base_offset := Vector2.ZERO

func _ready() -> void:
	player = Player.new()
	player.position = get_viewport_rect().size * 0.5
	add_child(player)
	waves = WaveManager.new()
	waves.arena = self
	add_child(waves)
	EventBus.screen_shake_requested.connect(_on_shake)
	EventBus.float_text_requested.connect(_on_float_text)

func _draw() -> void:
	var size := get_viewport_rect().size
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += GRID_SPACING
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += GRID_SPACING

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		position = _base_offset + Vector2(
			randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif position != _base_offset:
		position = _base_offset

func _on_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _on_float_text(at: Vector2, text: String, color: Color) -> void:
	var ft := FloatText.new()
	ft.position = at
	ft.text = text
	ft.color = color
	add_child(ft)

## Vide l'arène de tout ce qui n'est ni le joueur ni les systèmes.
func clear_transients() -> void:
	for child in get_children():
		if child == player or child == waves:
			continue
		child.queue_free()
