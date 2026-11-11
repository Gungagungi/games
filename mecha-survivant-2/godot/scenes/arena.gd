class_name Arena
extends Node2D
## Terrain de jeu : le niveau, le joueur, la caméra, le gestionnaire de vagues
## et tout ce qui est instancié en cours de partie.
##
## Le niveau (`level.gd`) est plus grand que l'écran : la caméra suit le mech,
## bornée aux limites de la carte. Le screen shake passe par l'`offset` de la
## caméra — décaler l'arène entière, comme avant, déplacerait la caméra avec
## elle et annulerait l'effet.

var level: Level
var player: Player
var waves: WaveManager
var camera: Camera2D

var _shake := 0.0
var _overview := false

func _ready() -> void:
	level = Level.new()
	add_child(level)
	player = Player.new()
	player.position = level.start_position()
	add_child(player)
	camera = Camera2D.new()
	var world := level.world_rect()
	camera.limit_left = int(world.position.x)
	camera.limit_top = int(world.position.y)
	camera.limit_right = int(world.end.x)
	camera.limit_bottom = int(world.end.y)
	add_child(camera)
	camera.make_current()
	snap_camera()
	if Level.overview_requested():
		_overview = true
		var view := get_viewport_rect().size
		var z := minf(view.x / world.size.x, view.y / world.size.y)
		camera.zoom = Vector2(z, z)
		camera.position = world.get_center()
	waves = WaveManager.new()
	waves.arena = self
	add_child(waves)
	EventBus.screen_shake_requested.connect(_on_shake)
	EventBus.float_text_requested.connect(_on_float_text)

## Recentre la caméra sur le mech sans transition (début de partie).
func snap_camera() -> void:
	if _overview:
		return
	camera.position = player.position
	camera.reset_smoothing()

func _process(delta: float) -> void:
	if _overview:
		return
	camera.position = player.position
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

func _on_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _on_float_text(at: Vector2, text: String, color: Color) -> void:
	var ft := FloatText.new()
	ft.position = at
	ft.text = text
	ft.color = color
	add_child(ft)

## Vide l'arène de tout ce qui n'est ni le niveau, ni le joueur, ni les
## systèmes.
func clear_transients() -> void:
	for child in get_children():
		if child == player or child == waves or child == level or child == camera:
			continue
		child.queue_free()
