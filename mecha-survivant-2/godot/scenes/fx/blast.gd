class_name Blast
extends Node2D
## Explosion purement visuelle, dessinée en code : un éclair plein qui
## s'éteint, un anneau de souffle qui s'élargit et quelques éclats. Les dégâts
## sont l'affaire de l'appelant (télégraphe, test de distance) — ce nœud ne
## touche jamais au joueur, il peut donc survivre au boss qui l'a lancé.

var radius := 80.0
var color := Color(1.0, 0.55, 0.2)
var duration := 0.45

var _t := 0.0
var _shards: Array[Vector2] = []

## Pose une explosion dans `host` (l'arène, en général). Différé : peut partir
## d'une mort de boss, remontée d'une collision de balle.
static func spawn(host: Node, at: Vector2, r: float,
		col: Color = Color(1.0, 0.55, 0.2)) -> void:
	if host == null or not is_instance_valid(host):
		return
	var b := Blast.new()
	b.position = at
	b.radius = r
	b.color = col
	host.call_deferred("add_child", b)

func _ready() -> void:
	z_index = 5
	for i in 10:
		_shards.append(Vector2.RIGHT.rotated(TAU * i / 10.0 + randf_range(-0.2, 0.2)))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		queue_free()

func _draw() -> void:
	var p := clampf(_t / duration, 0.0, 1.0)
	var fade := 1.0 - p
	draw_circle(Vector2.ZERO, radius * (0.45 + 0.35 * p), Color(color, 0.55 * fade))
	draw_circle(Vector2.ZERO, radius * 0.3 * fade, Color(1.0, 0.95, 0.75, fade))
	draw_arc(Vector2.ZERO, radius * (0.6 + 0.4 * p), 0.0, TAU, 40,
		Color(color.lightened(0.3), fade), 3.0 + 5.0 * fade)
	for d in _shards:
		var from := d * radius * (0.3 + 0.7 * p)
		draw_line(from, from + d * 10.0 * fade, Color(1.0, 0.9, 0.5, fade), 2.0)
