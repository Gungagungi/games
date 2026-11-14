class_name DestroyerRobot
extends EnemyBase
## Robot envoyé par le Destructeur d'univers : se tient à distance et lance
## des boules de métal. Pas d'entrée dans `EnemyStats` — il n'appartient à
## aucune vague ordinaire ; ses stats lui sont données par le boss à l'envoi.

const RANGE := 230.0
const THROW_INTERVAL := 2.2
const METAL := Color(0.62, 0.66, 0.72)

var ball_damage := 9.0
var _throw_cd := 1.2
var _body: Body

func _shape_kind() -> String:
	return "none" if SpriteOrShape.sheet_texture(_sprite_name()) == null else "square"

func _on_spawn() -> void:
	if SpriteOrShape.sheet_texture(_sprite_name()) == null:
		_body = Body.new()
		_visual.add_child(_body)

func _behaviour(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if dist > RANGE:
		_chase(delta)
	elif dist < RANGE * 0.6:
		_chase(delta, -0.6)
	_throw_cd -= delta
	if _throw_cd <= 0.0 and dist <= RANGE * 1.2:
		_throw_cd = THROW_INTERVAL * randf_range(0.85, 1.15)
		_throw()

func _throw() -> void:
	if _body != null:
		_body.wind()
	var dir := (player.global_position - global_position).normalized()
	var ball := EnemyProjectile.new()
	ball.setup(global_position + dir * 14.0, dir, 220.0, ball_damage, 7.0, METAL)
	get_parent().add_child(ball)


## Petit robot carré dessiné en code : chenilles, caisse d'acier, œil jaune,
## bras lanceur qui se replie à chaque tir.
class Body extends Node2D:
	const STEEL := Color(0.36, 0.39, 0.45)
	const STEEL_HI := Color(0.55, 0.59, 0.66)
	const DARK := Color(0.08, 0.08, 0.1)
	const EYE := Color(1.0, 0.86, 0.12)

	var _t := 0.0
	var _arm := 0.0

	func wind() -> void:
		_arm = 0.25

	func _process(delta: float) -> void:
		_t += delta
		_arm = maxf(0.0, _arm - delta)
		queue_redraw()

	func _draw() -> void:
		var bob := roundf(sin(_t * 9.0))
		draw_rect(Rect2(-13, 6, 26, 8), DARK)
		for i in 4:
			draw_rect(Rect2(-11 + i * 6 + int(_t * 20.0) % 3, 8, 3, 4), STEEL)
		draw_rect(Rect2(-11, -10 + bob, 22, 17), DARK)
		draw_rect(Rect2(-9, -8 + bob, 18, 13), STEEL)
		draw_rect(Rect2(-9, -8 + bob, 18, 3), STEEL_HI)
		draw_rect(Rect2(-5, -4 + bob, 10, 4), DARK)
		draw_rect(Rect2(-3, -3 + bob, 6, 2), EYE)
		draw_line(Vector2(0, -10 + bob), Vector2(0, -15 + bob), DARK, 2.0)
		draw_rect(Rect2(-1, -17 + bob, 2, 2), EYE)
		# Bras lanceur : tendu au repos, replié pendant le tir.
		var arm_y := -6.0 if _arm > 0.0 else -1.0
		draw_rect(Rect2(10, arm_y + bob, 6, 5), DARK)
		draw_circle(Vector2(17, arm_y + 2.5 + bob), 3.0, STEEL_HI)
