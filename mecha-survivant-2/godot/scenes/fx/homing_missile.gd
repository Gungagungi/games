class_name HomingMissile
extends Node2D
## Missile à tête chercheuse : part dans une direction donnée puis vire vers
## le mech avec un rayon de braquage limité — on l'esquive en changeant de cap
## au dernier moment. Explose au contact, sur un mur ou en fin de course, et
## blesse tout ce qui est dans le souffle.
##
## Le missile ne garde aucune référence à son lanceur : il survit au boss.

var direction := Vector2.RIGHT
var speed := 230.0
var turn_rate := 2.2
var damage := 20.0
var blast_radius := 60.0
var life := 4.5

const BOOM_TIME := 0.28
const BODY := Color(0.2, 0.21, 0.26)
const TIP := Color(1.0, 0.86, 0.12)
const FLAME := Color(1.0, 0.55, 0.15)

var _boom := -1.0
var _t := 0.0

func _process(delta: float) -> void:
	if not GameState.running:
		return
	_t += delta
	if _boom >= 0.0:
		_boom += delta
		queue_redraw()
		if _boom >= BOOM_TIME:
			queue_free()
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and p.alive:
		var want := (p.global_position - global_position).angle()
		var diff := wrapf(want - direction.angle(), -PI, PI)
		direction = direction.rotated(clampf(diff, -turn_rate * delta, turn_rate * delta))
	position += direction * speed * delta
	life -= delta
	rotation = direction.angle()
	queue_redraw()
	if life <= 0.0 or Level.blocks_projectile(position):
		_explode()
	elif p != null and p.alive and position.distance_to(p.global_position) <= 22.0:
		_explode()

func _explode() -> void:
	_boom = 0.0
	rotation = 0.0
	AudioManager.sfx("shockwave")
	EventBus.screen_shake_requested.emit(5.0)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and p.alive and p.global_position.distance_to(global_position) <= blast_radius + 12.0:
		p.take_damage(damage)

func _draw() -> void:
	if _boom >= 0.0:
		var k := _boom / BOOM_TIME
		draw_circle(Vector2.ZERO, blast_radius * (0.4 + 0.6 * k), Color(FLAME, 0.55 * (1.0 - k)))
		draw_circle(Vector2.ZERO, blast_radius * 0.5 * (1.0 - k), Color(TIP, 0.8 * (1.0 - k)))
		return
	# Flamme de réacteur qui vacille, corps, ailerons, ogive jaune.
	var flick := 6.0 + 3.0 * sin(_t * 40.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -3), Vector2(-8 - flick, 0),
		Vector2(-8, 3)]), FLAME)
	draw_rect(Rect2(-9, -4, 16, 8), Color.BLACK)
	draw_rect(Rect2(-8, -3, 14, 6), BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -3), Vector2(-4, -3), Vector2(-9, -7)]), BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 3), Vector2(-4, 3), Vector2(-9, 7)]), BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -3), Vector2(11, 0), Vector2(6, 3)]), TIP)
