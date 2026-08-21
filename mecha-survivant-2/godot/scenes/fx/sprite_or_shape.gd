class_name SpriteOrShape
extends Node2D
## Visuel d'entité tolérant à l'absence d'asset.
##
## Tant qu'aucun PNG n'a été déposé dans `assets/sprites/`, l'entité se dessine en
## placeholder géométrique (comme la v1 Canvas 2D). Dès que le fichier attendu
## existe, il est affiché à sa place — sans changer une ligne du code appelant.
## Voir `assets/MANIFEST.md` pour la liste des fichiers et leur découpage.

@export var texture_name: String = ""
@export var frame_count: int = 1
@export var fps: float = 8.0
@export var radius: float = 16.0
@export var shape_color: Color = Color.WHITE
@export var shape: String = "circle" ## circle | diamond | square

var _sprite: Sprite2D = null
var _time: float = 0.0

func _ready() -> void:
	var path := "res://assets/sprites/%s.png" % texture_name
	if texture_name != "" and ResourceLoader.exists(path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(path)
		_sprite.hframes = maxi(1, frame_count)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)

func _process(delta: float) -> void:
	_time += delta
	if _sprite != null:
		if frame_count > 1:
			_sprite.frame = int(_time * fps) % frame_count
	else:
		queue_redraw()

func _draw() -> void:
	if _sprite != null:
		return
	# Placeholder : disque plein, liseré plus clair, et un point de "regard"
	# pour que l'orientation reste lisible sans sprite.
	var pulse := 1.0 + 0.04 * sin(_time * 6.0)
	var r := radius * pulse
	match shape:
		"diamond":
			var pts := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
			draw_colored_polygon(pts, shape_color)
			draw_polyline(pts + PackedVector2Array([pts[0]]), shape_color.lightened(0.4), 2.0)
		"square":
			var rect := Rect2(-r, -r, r * 2.0, r * 2.0)
			draw_rect(rect, shape_color)
			draw_rect(rect, shape_color.lightened(0.4), false, 2.0)
		_:
			draw_circle(Vector2.ZERO, r, shape_color)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, shape_color.lightened(0.45), 2.0)

func flash() -> void:
	modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)
