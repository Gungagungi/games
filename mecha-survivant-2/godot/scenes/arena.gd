class_name Arena
extends Node2D
## Terrain de jeu : le sol, le joueur, le gestionnaire de vagues et tout ce qui
## est instancié en cours de partie. Le screen shake s'applique ici, en décalant
## l'ensemble.
##
## Le sol se dessine de deux façons : dalles de `tiles_floor.png` si la planche
## a été déposée, sinon la grille de la v1. Pas de TileMap — les dalles sont
## posées à même `_draw()`, ce qui suffit pour un fond fixe et garde la scène
## minimaliste (voir CLAUDE.md).

const GRID_SPACING := 40.0
const GRID_COLOR := Color(0.23, 0.28, 0.38, 0.16)
const FLOOR_SHEET := "tiles_floor"
const TILE_SIZE := 32.0

var player: Player
var waves: WaveManager

var _shake := 0.0
var _base_offset := Vector2.ZERO
var _floor: Texture2D = null

func _ready() -> void:
	_floor = SpriteOrShape.sheet_texture(FLOOR_SHEET)
	player = Player.new()
	player.position = get_viewport_rect().size * 0.5
	add_child(player)
	waves = WaveManager.new()
	waves.arena = self
	add_child(waves)
	EventBus.screen_shake_requested.connect(_on_shake)
	EventBus.float_text_requested.connect(_on_float_text)

func _draw() -> void:
	if _floor != null:
		_draw_floor()
	else:
		_draw_grid()

## Dalles posées en damier. La variante d'une case est tirée d'un hachage de ses
## coordonnées : le motif est bruité mais stable d'une frame à l'autre, sans
## avoir à mémoriser la grille.
func _draw_floor() -> void:
	var size := get_viewport_rect().size
	var variants := SpriteOrShape.sheet_frames(FLOOR_SHEET)
	var src := Vector2(_floor.get_width() / float(variants), _floor.get_height())
	# Une case de marge de chaque côté : le screen shake décale l'arène entière,
	# et découvrirait sinon une bande vide au bord de l'écran.
	var cols := int(ceil(size.x / TILE_SIZE)) + 2
	var rows := int(ceil(size.y / TILE_SIZE)) + 2
	for cy in rows:
		for cx in cols:
			var v := absi(hash(Vector2i(cx, cy))) % variants
			draw_texture_rect_region(_floor,
				Rect2((cx - 1) * TILE_SIZE, (cy - 1) * TILE_SIZE, TILE_SIZE, TILE_SIZE),
				Rect2(Vector2(v * src.x, 0.0), src))

func _draw_grid() -> void:
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
