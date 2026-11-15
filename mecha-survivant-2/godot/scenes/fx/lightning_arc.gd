class_name LightningArc
extends Node2D
## Éclair tiré de l'antenne du Robot géant mutant. L'antenne crépite et un
## cercle marque, au sol, le point visé (`target`, la position du mech au
## départ) pendant `windup` ; puis la foudre tombe.
##
## Si le mech est dans le cercle à cet instant, l'arc **s'accroche** à lui :
## `dps_ratio` de ses PV max par seconde pendant `hold` secondes (5 %/s sur
## 3 s par défaut), via `Player.take_dot_damage()`. Un bouclier actif
## encaisse en premier — l'éclair l'entame dès l'accroche, puis passe aux PV
## une fois le bouclier à sec. Ni bouclier ni dash ne le décrochent : c'est
## l'impact qu'il faut esquiver. Sinon, il frappe le sol et s'éteint.

const STRIKE_RADIUS := 56.0
const MISS_TIME := 0.25
const BOLT := Color(0.55, 0.85, 1.0)
const BOLT_CORE := Color(0.95, 1.0, 1.0)

var source: Node2D
var offset := Vector2.ZERO
var target := Vector2.ZERO
var windup := 0.9
var hold := 3.0
var dps_ratio := 0.05

var _t := 0.0
var _struck := false
var _latched := false
var _end_at := 0.0
var _antenna := Vector2.ZERO
var _seed := 0

func _ready() -> void:
	z_index = 4
	AudioManager.sfx("laser_charge")
	_end_at = windup + MISS_TIME

func _process(delta: float) -> void:
	if not GameState.running:
		return
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	_antenna = source.global_position + offset
	_t += delta
	_seed = int(_t * 30.0)
	var p := get_tree().get_first_node_in_group("player") as Player
	if not _struck and _t >= windup:
		_struck = true
		EventBus.screen_shake_requested.emit(8.0)
		if p != null and p.alive and p.global_position.distance_to(target) <= STRIKE_RADIUS:
			_latched = true
			_end_at = windup + hold
			EventBus.float_text_requested.emit(p.global_position + Vector2(0, -30),
				"ÉLECTROCUTÉ", BOLT)
	if _latched:
		if p == null or not p.alive:
			queue_free()
			return
		target = p.global_position
		p.take_dot_damage(p.max_hp * dps_ratio * delta, true)
	queue_redraw()
	if _t >= _end_at:
		queue_free()

## Ligne brisée de l'antenne au point d'impact, redessinée à chaque image.
func _bolt(from: Vector2, to: Vector2, jitter: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var pts := PackedVector2Array([from])
	var steps := maxi(4, int(from.distance_to(to) / 22.0))
	var normal := (to - from).normalized().orthogonal()
	for i in range(1, steps):
		pts.append(from.lerp(to, float(i) / steps) + normal * rng.randf_range(-jitter, jitter))
	pts.append(to)
	return pts

func _draw() -> void:
	var a := _antenna - global_position
	var tgt := target - global_position
	if not _struck:
		var f := clampf(_t / windup, 0.0, 1.0)
		# Antenne qui crépite, et le point visé au sol.
		for i in 3:
			var d := Vector2.RIGHT.rotated(_seed * 1.7 + i * 2.1) * (6.0 + 8.0 * f)
			draw_polyline(_bolt(a, a + d, 3.0), Color(BOLT, 0.8), 1.5)
		draw_circle(a, 3.0 + 4.0 * f, Color(BOLT_CORE, 0.6 + 0.4 * f))
		draw_arc(tgt, STRIKE_RADIUS, 0.0, TAU, 32, Color(BOLT, 0.4 + 0.4 * f), 2.0)
		draw_circle(tgt, STRIKE_RADIUS * f, Color(BOLT, 0.14))
		return
	var pts := _bolt(a, tgt, 14.0)
	draw_polyline(pts, Color(BOLT, 0.35), 9.0)
	draw_polyline(pts, BOLT, 4.0)
	draw_polyline(pts, BOLT_CORE, 1.5)
	draw_circle(tgt, 10.0 + 3.0 * sin(_t * 40.0), Color(BOLT_CORE, 0.7))
	if _latched:
		draw_arc(tgt, 20.0, 0.0, TAU, 20, Color(BOLT, 0.6), 2.0)
