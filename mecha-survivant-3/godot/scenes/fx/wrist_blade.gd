class_name WristBlade
extends Node2D
## Lame qui jaillit du poignet d'un boss (le Destructeur d'univers) : elle
## sort pendant `windup` en suivant le mech, puis fauche un arc de `arc`
## radians en `swing` secondes. Ne blesse qu'une fois par coup.
##
## Le nœud vit dans l'arène, pas sous le boss, et suit `source` décalé de
## `offset` (le gantelet). Il disparaît avec sa source.

var source: Node2D
var offset := Vector2.ZERO
var damage := 30.0
var length := 190.0
var windup := 0.55
var swing := 0.22
var arc := 2.4
var color := Color(1.0, 0.86, 0.12)

const FADE := 0.18
const STEEL := Color(0.78, 0.82, 0.9)

var _t := 0.0
var _aim := 0.0
## Sens du fauchage : +1 horaire, -1 antihoraire.
var _dir := 1.0
var _blade_angle := 0.0
var _hit := false

func _ready() -> void:
	_dir = -1.0 if randf() < 0.5 else 1.0
	_follow()
	_aim = _aim_at_player(_aim)
	_blade_angle = _aim - arc * 0.5 * _dir
	AudioManager.sfx("dash")

func _follow() -> void:
	if source != null and is_instance_valid(source):
		global_position = source.global_position + offset

func _aim_at_player(fallback: float) -> float:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return fallback
	return (p.global_position - global_position).angle()

func _process(delta: float) -> void:
	if not GameState.running:
		return
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	_follow()
	_t += delta
	if _t < windup:
		# La lame sort en visant le mech : le coup part de là où il est.
		_aim = _aim_at_player(_aim)
		_blade_angle = _aim - arc * 0.5 * _dir
	elif _t < windup + swing:
		var k := (_t - windup) / swing
		var before := _blade_angle
		_blade_angle = _aim - arc * 0.5 * _dir + arc * k * _dir
		_check_hit(before, _blade_angle)
	elif _t >= windup + swing + FADE:
		queue_free()
		return
	queue_redraw()

## Touche si le mech est à portée de lame et que celle-ci vient de balayer
## son angle — test par secteur, pas par segment, pour ne rien rater entre
## deux images.
func _check_hit(from: float, to: float) -> void:
	if _hit:
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	var rel := p.global_position - global_position
	if rel.length() > length + 16.0:
		return
	var a := wrapf(rel.angle() - from, -PI, PI) * _dir
	var span := absf(to - from) + 0.12
	if a >= -0.12 and a <= span:
		p.take_damage(damage)
		_hit = true
		EventBus.screen_shake_requested.emit(10.0)

func _draw() -> void:
	var out := clampf(_t / windup, 0.0, 1.0)
	var len := length * out
	var fade := 1.0
	if _t > windup + swing:
		fade = 1.0 - clampf((_t - windup - swing) / FADE, 0.0, 1.0)
	# Pendant la sortie : le secteur qui va être fauché, en avertissement.
	if _t < windup:
		var pts := PackedVector2Array([Vector2.ZERO])
		var start := _aim - arc * 0.5
		for i in 25:
			pts.append(Vector2.RIGHT.rotated(start + arc * i / 24.0) * length)
		draw_colored_polygon(pts, Color(color, 0.08 + 0.12 * out))
	# Traînée du fauchage.
	if _t >= windup:
		var trail := PackedVector2Array([Vector2.ZERO])
		var from := _aim - arc * 0.5 * _dir
		for i in 13:
			trail.append(Vector2.RIGHT.rotated(lerpf(from, _blade_angle, i / 12.0)) * length)
		draw_colored_polygon(trail, Color(color, 0.22 * fade))
	# La lame : un long triangle d'acier au fil jaune.
	var d := Vector2.RIGHT.rotated(_blade_angle)
	var n := d.orthogonal()
	var blade := PackedVector2Array([n * 7.0, d * len * 0.92 + n * 4.0, d * len,
		d * len * 0.92 - n * 4.0, -n * 7.0])
	draw_colored_polygon(blade, Color(STEEL, fade))
	draw_line(Vector2.ZERO, d * len, Color(color, fade), 2.0)
	draw_polyline(blade + PackedVector2Array([blade[0]]), Color(0, 0, 0, fade), 2.0)
	# Garde au poignet.
	draw_rect(Rect2(-6, -6, 12, 12), Color(0.06, 0.06, 0.08, fade))
	draw_rect(Rect2(-3, -3, 6, 6), Color(color, fade))
