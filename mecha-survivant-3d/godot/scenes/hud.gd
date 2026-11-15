extends Control
# Interface dessinée en code : réticule, barre de vie, radar, recharge du
# dash, commandes tactiles, et le voile rouge des coups reçus.
#
# Le radar compense le défaut de la vue à la 3e personne relevé avant le
# prototype : on ne voit plus ce qui arrive dans le dos. Il est orienté comme
# la caméra (le haut du radar = devant soi).

const RADAR_RANGE := 40.0
const RADAR_SIZE := 78.0

var game: Node  # main.gd, lu à chaque frame

var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var vp := get_viewport_rect().size
	var mech = game.mech
	# Voile rouge des coups reçus.
	if game.hurt_vignette > 0.0:
		var a: float = game.hurt_vignette * 0.45
		var w := vp.x * 0.12
		draw_rect(Rect2(0, 0, w, vp.y), Color(0.8, 0, 0, a * 0.6))
		draw_rect(Rect2(vp.x - w, 0, w, vp.y), Color(0.8, 0, 0, a * 0.6))
		draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.6, 0, 0, a * 0.25))

	if not game.in_play():
		return

	# Réticule.
	var c := vp * 0.5
	var col := Color(1, 1, 1, 0.85)
	if game.aim_on_enemy:
		col = Color(1, 0.35, 0.25, 0.95)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * 6.0, c + d * 16.0, col, 2.0)
	draw_circle(c, 1.8, col)

	# Barre de vie.
	var bar := Rect2(24, vp.y - 46, 300, 18)
	draw_rect(bar.grow(3), Color(0, 0, 0, 0.6))
	var ratio: float = mech.hp / mech.MAX_HP
	var hp_col := Color(0.3, 0.85, 0.4).lerp(Color(0.95, 0.2, 0.15), 1.0 - ratio)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), hp_col)
	draw_string(_font, bar.position + Vector2(6, -8), "BLINDAGE  %d / %d" % [ceili(mech.hp), int(mech.MAX_HP)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))

	# Recharge du dash.
	var dash_bar := Rect2(24, vp.y - 18, 140, 6)
	draw_rect(dash_bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(dash_bar.position, Vector2(dash_bar.size.x * mech.dash_ready(), dash_bar.size.y)), Color(0.3, 0.8, 1.0))

	# Vague et éliminations.
	draw_string(_font, Vector2(24, 40), "VAGUE %d" % game.wave, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.85, 0.5))
	draw_string(_font, Vector2(24, 66), "%d détruits  ·  %d restants" % [game.kills, game.remaining()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))

	_draw_radar(Vector2(vp.x - RADAR_SIZE - 24, RADAR_SIZE + 24))
	if game.touch_mode:
		_draw_touch(vp)


func _draw_radar(center: Vector2) -> void:
	draw_circle(center, RADAR_SIZE + 3, Color(0, 0, 0, 0.55))
	draw_circle(center, RADAR_SIZE, Color(0.05, 0.12, 0.1, 0.75))
	draw_arc(center, RADAR_SIZE * 0.5, 0, TAU, 40, Color(0.3, 1, 0.6, 0.18), 1.0)
	draw_arc(center, RADAR_SIZE, 0, TAU, 48, Color(0.3, 1, 0.6, 0.5), 1.5)
	# Champ de vision de la caméra.
	var half_fov := deg_to_rad(38.0)
	for s in [-1.0, 1.0]:
		var d := Vector2(sin(half_fov * s), -cos(half_fov * s))
		draw_line(center, center + d * RADAR_SIZE, Color(0.3, 1, 0.6, 0.25), 1.0)
	var yaw: float = game.cam_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var me: Vector3 = game.mech.position
	var k := RADAR_SIZE / RADAR_RANGE
	for e in game.enemies:
		var v: Vector3 = e.position - me
		var p := Vector2(v.dot(right), -v.dot(fwd)) * k
		var behind := v.dot(fwd) < 0.0
		var r := 3.0 if e.kind != "brute" else 5.0
		if p.length() > RADAR_SIZE - 4:
			# Hors de portée : un repère sur le bord, pour savoir d'où ça vient.
			p = p.normalized() * (RADAR_SIZE - 4)
			r = 2.0
		var col := Color(1, 0.3, 0.2) if behind else Color(1, 0.75, 0.3)
		draw_circle(center + p, r, col)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -6), center + Vector2(4, 4), center + Vector2(-4, 4)]), Color(0.5, 1, 1))


func _draw_touch(vp: Vector2) -> void:
	if game.touch_stick_active:
		var o: Vector2 = game.touch_stick_origin
		draw_arc(o, 70, 0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(o + game.touch_stick_vec * 70.0, 26, Color(1, 1, 1, 0.3))
	else:
		draw_string(_font, Vector2(30, vp.y - 80), "← glisser pour marcher", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.4))
	var dash_c: Vector2 = game.dash_button_center()
	draw_circle(dash_c, game.DASH_BUTTON_R, Color(0.3, 0.8, 1.0, 0.18 + 0.25 * game.mech.dash_ready()))
	draw_string(_font, dash_c + Vector2(-24, 6), "DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
