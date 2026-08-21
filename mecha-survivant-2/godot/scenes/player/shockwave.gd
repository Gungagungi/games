class_name Shockwave
extends Node2D
## Anneau de l'onde de choc. Purement visuel : les dégâts sont appliqués
## d'un coup par le joueur au déclenchement.

const DURATION := 0.35

var max_radius := 140.0
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := _t / DURATION
	var r := max_radius * ease(p, 0.4)
	var alpha := 1.0 - p
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.45, 0.85, 1.0, alpha), 6.0)
	draw_arc(Vector2.ZERO, r * 0.75, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, alpha * 0.5), 3.0)
