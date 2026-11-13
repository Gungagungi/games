class_name GoldenGem
extends Node2D
## Gemme dorée lâchée par le Destructeur d'univers. La ramasser termine le
## niveau spécial — et le jeu : `EventBus.golden_gem_collected`.
##
## Dessinée en code (pas de planche) : un losange taillé qui flotte, entouré
## d'un halo et d'éclats. Elle attire le mech quand il passe à proximité, pour
## qu'on ne la rate pas d'un pixel. En smoke, personne ne vient la chercher :
## elle se ramasse seule au bout d'une seconde.

const PICKUP_RADIUS := 34.0
const MAGNET_RADIUS := 140.0
const MAGNET_SPEED := 260.0
const SIZE := 18.0
const GOLD := Color(1.0, 0.82, 0.25)
const GOLD_DARK := Color(0.78, 0.5, 0.08)
const GOLD_LIGHT := Color(1.0, 0.96, 0.7)

var _t := 0.0
var _taken := false

func _ready() -> void:
	z_index = 5
	EventBus.float_text_requested.emit(global_position + Vector2(0, -40),
		"GEMME DORÉE", GOLD)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _taken or not GameState.running:
		return
	if GameState.smoke_test:
		if _t >= 1.0:
			_collect()
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	var d := global_position.distance_to(p.global_position)
	if d <= PICKUP_RADIUS:
		_collect()
	elif d <= MAGNET_RADIUS:
		global_position = global_position.move_toward(p.global_position, MAGNET_SPEED * delta)

func _collect() -> void:
	_taken = true
	AudioManager.sfx("upgrade_pick")
	EventBus.screen_shake_requested.emit(8.0)
	EventBus.golden_gem_collected.emit()
	queue_free()

func _draw() -> void:
	var bob := Vector2(0.0, sin(_t * 3.0) * 4.0)
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(bob, SIZE * 2.4, Color(GOLD, 0.10 + 0.08 * glow))
	draw_circle(bob, SIZE * 1.6, Color(GOLD, 0.16 + 0.10 * glow))
	# Éclats qui tournent autour de la gemme.
	for i in 4:
		var a := _t * 1.5 + TAU * i / 4.0
		var at := bob + Vector2.RIGHT.rotated(a) * SIZE * 2.0
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(GOLD_LIGHT, 0.8))
	# Taille en losange : couronne (haut) et pavillon (bas), facettes ombrées.
	var top := bob + Vector2(0, -SIZE)
	var bottom := bob + Vector2(0, SIZE * 1.15)
	var left := bob + Vector2(-SIZE * 0.85, -SIZE * 0.2)
	var right := bob + Vector2(SIZE * 0.85, -SIZE * 0.2)
	var mid := bob + Vector2(0, -SIZE * 0.2)
	draw_colored_polygon(PackedVector2Array([top, right, mid]), GOLD_LIGHT)
	draw_colored_polygon(PackedVector2Array([top, mid, left]), GOLD)
	draw_colored_polygon(PackedVector2Array([left, mid, bottom]), GOLD_DARK)
	draw_colored_polygon(PackedVector2Array([mid, right, bottom]), GOLD)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]),
		Color(0.35, 0.2, 0.0), 2.0)
	draw_line(left, right, Color(0.35, 0.2, 0.0, 0.6), 1.0)
	# Reflet qui clignote.
	draw_circle(bob + Vector2(-SIZE * 0.25, -SIZE * 0.5), 2.5, Color(1, 1, 1, glow))
