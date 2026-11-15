class_name ChainFlail
extends Node2D
## Boule piquante au bout d'une chaîne, frappe de l'Esclave du Destructeur
## d'univers. Trois temps : elle tournoie autour de la main (`windup`, le
## signal pour esquiver), file en ligne droite vers le point visé au lancer
## (`target`, pas le mech lui-même : un pas de côté suffit), puis revient.
##
## Elle blesse au contact, une fois par lancer, à l'aller comme au retour.
## Le nœud suit sa source et meurt avec elle — c'est un bras, pas un projectile.

const BALL_RADIUS := 15.0
const SPIN_RADIUS := 34.0
const LINK_STEP := 11.0
const STEEL := Color(0.5, 0.52, 0.58)
const STEEL_DARK := Color(0.22, 0.23, 0.27)
const OUTLINE := Color(0.0, 0.0, 0.0)

var source: Node2D
var offset := Vector2.ZERO
var target := Vector2.ZERO
var damage := 20.0
var reach := 300.0
var windup := 0.6
var out_time := 0.4
var back_time := 0.45

var _t := 0.0
var _hit := false
var _ball := Vector2.ZERO
var _hand := Vector2.ZERO
var _thrown_from := Vector2.ZERO
var _thrown_to := Vector2.ZERO

func _ready() -> void:
	z_index = 2
	if source != null and is_instance_valid(source):
		_hand = source.global_position + offset
	_ball = _hand

func is_done() -> bool:
	return _t >= windup + out_time + back_time

func _process(delta: float) -> void:
	if not GameState.running:
		return
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	_hand = source.global_position + offset
	_t += delta
	if _t < windup:
		var a := _t / windup * TAU * 2.0
		_ball = _hand + Vector2(cos(a), sin(a) * 0.5) * SPIN_RADIUS
	elif _t < windup + out_time:
		if _thrown_to == Vector2.ZERO:
			_thrown_from = _ball
			var to := target - _hand
			_thrown_to = _hand + to.limit_length(reach)
			AudioManager.sfx("enemy_shoot")
		var f := (_t - windup) / out_time
		_ball = _thrown_from.lerp(_thrown_to, 1.0 - pow(1.0 - f, 2.0))
	elif not is_done():
		var f := (_t - windup - out_time) / back_time
		_ball = _thrown_to.lerp(_hand, f * f)
	else:
		queue_free()
		return
	if _t >= windup and not _hit:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p != null and p.alive \
				and p.global_position.distance_to(_ball) <= BALL_RADIUS + 14.0:
			_hit = true
			p.take_damage(damage)
			EventBus.screen_shake_requested.emit(8.0)
	queue_redraw()

func _draw() -> void:
	# Dessin en coordonnées locales : le nœud reste à l'origine de l'arène.
	var hand := _hand - global_position
	var ball := _ball - global_position
	var span := ball - hand
	var links := maxi(1, int(span.length() / LINK_STEP))
	for i in links:
		var at := hand + span * (float(i) + 0.5) / links
		var horizontal := i % 2 == 0
		var size := Vector2(8, 5) if horizontal else Vector2(5, 8)
		var r := Rect2(at - size * 0.5, size)
		draw_rect(r.grow(1.0), OUTLINE)
		draw_rect(r, STEEL_DARK)
		draw_rect(r.grow(-1.5), OUTLINE)
	# Boule : pointes en étoile, puis le corps biseauté.
	var spin := _t * 9.0
	for i in 8:
		var d := Vector2.RIGHT.rotated(spin + TAU * i / 8.0)
		var tip := ball + d * (BALL_RADIUS + 8.0)
		var side := d.orthogonal() * 4.0
		var spike := PackedVector2Array([ball + d * BALL_RADIUS * 0.7 + side, tip,
			ball + d * BALL_RADIUS * 0.7 - side])
		draw_colored_polygon(spike, STEEL.lightened(0.2))
		draw_polyline(spike, OUTLINE, 1.0)
	draw_circle(ball, BALL_RADIUS + 2.0, OUTLINE)
	draw_circle(ball, BALL_RADIUS, STEEL)
	draw_circle(ball + Vector2(-4, -4), BALL_RADIUS * 0.45, STEEL.lightened(0.35))
	draw_circle(ball + Vector2(4, 5), BALL_RADIUS * 0.35, STEEL_DARK)
