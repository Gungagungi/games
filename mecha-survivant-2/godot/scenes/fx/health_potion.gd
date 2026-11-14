class_name HealthPotion
extends Node2D
## Potion de soin du niveau spécial, posée sur la carte par le Destructeur
## d'univers (`DestroyerBoss._drop_potion()`). La ramasser rend `HEAL_RATIO`
## des PV max du mech et éteint son embrasement.
##
## Dessinée en code, comme la gemme dorée : une fiole ronde au liquide rouge
## qui ondule, bouchon de liège, halo. Elle attire le mech de près, et finit
## par s'évaporer : elle clignote pendant ses `BLINK_TIME` dernières secondes.
## En smoke, elle se ramasse seule pour que `check.sh` passe par le soin.

const HEAL_RATIO := 0.3
const LIFETIME := 22.0
const BLINK_TIME := 5.0
const PICKUP_RADIUS := 26.0
const MAGNET_RADIUS := 90.0
const MAGNET_SPEED := 200.0
const GLASS := Color(0.75, 0.9, 1.0, 0.55)
const LIQUID := Color(0.9, 0.12, 0.2)
const LIQUID_DARK := Color(0.55, 0.04, 0.1)
const LIQUID_LIGHT := Color(1.0, 0.5, 0.55)
const CORK := Color(0.6, 0.4, 0.2)
const CORK_DARK := Color(0.38, 0.24, 0.1)
const OUTLINE := Color(0.08, 0.05, 0.07)

var _t := 0.0
var _taken := false

func _ready() -> void:
	z_index = 4
	add_to_group("potions")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _taken or not GameState.running:
		return
	if _t >= LIFETIME:
		queue_free()
		return
	if GameState.smoke_test:
		if _t >= 1.5:
			var sp := get_tree().get_first_node_in_group("player") as Player
			if sp != null:
				_collect(sp)
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	var d := global_position.distance_to(p.global_position)
	if d <= PICKUP_RADIUS:
		_collect(p)
	elif d <= MAGNET_RADIUS:
		global_position = global_position.move_toward(p.global_position, MAGNET_SPEED * delta)

func _collect(p: Player) -> void:
	_taken = true
	if GameState.smoke_test:
		print("[smoke] potion de soin ramassée")
	p.heal(p.max_hp * HEAL_RATIO)
	AudioManager.sfx("upgrade_pick")
	queue_free()

func _draw() -> void:
	# Clignote avant de s'évaporer : une frame sur deux à 8 Hz.
	if _t > LIFETIME - BLINK_TIME and fmod(_t * 8.0, 1.0) < 0.5:
		return
	# Apparition : la fiole grossit en un quart de seconde.
	var s := clampf(_t * 4.0, 0.0, 1.0)
	draw_set_transform(Vector2(0.0, sin(_t * 3.0) * 3.0), 0.0, Vector2(s, s))
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	# Ombre au sol (hors du flottement : compensée par -bob).
	draw_circle(Vector2(0, 16 - sin(_t * 3.0) * 3.0), 9.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(0, 2), 22.0, Color(LIQUID, 0.10 + 0.08 * glow))
	draw_circle(Vector2(0, 2), 15.0, Color(LIQUID_LIGHT, 0.08 + 0.06 * glow))
	# Panse : contour, verre, puis liquide aux deux tiers.
	var belly := Vector2(0, 4)
	draw_circle(belly, 11.0, OUTLINE)
	draw_circle(belly, 9.0, GLASS)
	var level := belly.y - 2.0
	var pts := PackedVector2Array()
	for i in 9:
		var x := -8.0 + 2.0 * i
		pts.append(Vector2(x, level + sin(_t * 5.0 + x * 0.6) * 1.2))
	for i in 9:
		var a := PI * i / 8.0
		pts.append(belly + Vector2(cos(a), sin(a)) * 8.6)
	draw_colored_polygon(pts, LIQUID)
	draw_circle(belly + Vector2(2, 4), 4.0, LIQUID_DARK)
	# Bulles qui remontent.
	for i in 3:
		var f := fmod(_t * 0.8 + i * 0.33, 1.0)
		draw_circle(Vector2(-4 + i * 4, belly.y + 6 - f * 8), 1.0, Color(LIQUID_LIGHT, 1.0 - f))
	# Col et bouchon.
	draw_rect(Rect2(-5, -10, 10, 8), OUTLINE)
	draw_rect(Rect2(-3, -9, 6, 7), GLASS)
	draw_rect(Rect2(-6, -16, 12, 7), OUTLINE)
	draw_rect(Rect2(-4, -15, 8, 5), CORK)
	draw_rect(Rect2(-4, -11, 8, 1), CORK_DARK)
	# Reflet du verre et croix de soin.
	draw_rect(Rect2(-6, -1, 2, 5), Color(1, 1, 1, 0.7))
	draw_rect(Rect2(-1, 3, 2, 6), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(-3, 5, 6, 2), Color(1, 1, 1, 0.85))
	# Étincelles qui tournent.
	for i in 3:
		var a := _t * 2.0 + TAU * i / 3.0
		var at := Vector2(0, 2) + Vector2.RIGHT.rotated(a) * 18.0
		draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color(LIQUID_LIGHT, 0.4 + 0.5 * glow))
	draw_set_transform(Vector2.ZERO)
