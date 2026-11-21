class_name Hud
extends Control
## Interface de jeu, dessinée en `_draw()` à chaque frame : réticule, barres
## (vie, bouclier, endurance), compétences et leurs recharges, vague et
## pouvoirs, radar, commandes tactiles, voiles des coups et des brûlures.
##
## Le radar répond au défaut de la vue à l'épaule dans un jeu de hordes : on
## ne voit plus derrière soi. Il est orienté comme la caméra (le haut =
## devant) ; ce qui arrive dans le dos y est en rouge.

const RADAR_RANGE := 40.0
const RADAR_SIZE := 78.0
const SLOT := 58.0
const ICON_SIZE := 32

var game: Node   ## main.gd, lu à chaque frame

var _font: Font
var _icons: Texture2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	if ResourceLoader.exists("res://assets/ui/ui_upgrades.png"):
		_icons = load("res://assets/ui/ui_upgrades.png")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var vp := get_viewport_rect().size
	var mech: Mech = game.mech
	_draw_vignettes(vp, mech)
	if not game.in_play():
		return
	_draw_crosshair(vp * 0.5)
	_draw_top_left()
	_draw_bars(vp, mech)
	if not GameState.touch_mode:
		_draw_skills(Vector2(24, vp.y - 24 - SLOT - 92), mech)
	_draw_radar(Vector2(vp.x - RADAR_SIZE - 24, RADAR_SIZE + 24))
	if GameState.touch_mode:
		_draw_touch(vp, mech)

func _draw_vignettes(vp: Vector2, mech: Mech) -> void:
	if game.hurt_vignette > 0.0:
		_edge_glow(vp, Color(0.75, 0.0, 0.0), game.hurt_vignette * 0.5, true)
	if mech.burn_time > 0.0 and game.in_play():
		var a := 0.3 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
		_edge_glow(vp, Color(1.0, 0.4, 0.05), a, false)

## Dégradé depuis les bords de l'écran, en bandes de plus en plus pâles :
## les côtés pour les coups reçus, le bas seul pour l'embrasement.
func _edge_glow(vp: Vector2, col: Color, strength: float, sides: bool) -> void:
	const BANDS := 10
	var depth := vp.y * 0.22
	for i in BANDS:
		var t := float(i) / BANDS
		var a := strength * (1.0 - t) * (1.0 - t) / BANDS * 2.2
		var w := depth * (1.0 - t)
		var c := Color(col, a)
		draw_rect(Rect2(0, vp.y - w, vp.x, w), c)
		if sides:
			draw_rect(Rect2(0, 0, w, vp.y), c)
			draw_rect(Rect2(vp.x - w, 0, w, vp.y), c)
			draw_rect(Rect2(0, 0, vp.x, w), c)

func _draw_crosshair(c: Vector2) -> void:
	var col := Color(1, 1, 1, 0.85)
	if game.camera.aim_enemy != null:
		col = Color(1, 0.35, 0.25, 0.95)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * 6.0, c + d * 16.0, col, 2.0)
	draw_circle(c, 1.8, col)

func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.75))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw_top_left() -> void:
	_text(Vector2(24, 42), "VAGUE %d / %d" % [GameState.wave, GameState.FINAL_WAVE], 30, Color(1, 0.85, 0.5))
	_text(Vector2(24, 68), "%d détruits  ·  %d restants" % [game.kills, game.waves.remaining()],
		18, Color(1, 1, 1, 0.85))
	var powers := UpgradeManager.summary()
	if powers != "":
		_text(Vector2(24, 92), powers, 15, Color(0.85, 0.8, 0.65, 0.9))

func _bar(rect: Rect2, ratio: float, col: Color, label: String) -> void:
	draw_rect(rect.grow(2), Color(0, 0, 0, 0.6))
	draw_rect(rect, Color(0.08, 0.1, 0.14, 0.9))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), col)
	_text(rect.position + Vector2(6, rect.size.y - 3), label, 14, Color(1, 1, 1, 0.92))

func _draw_bars(vp: Vector2, mech: Mech) -> void:
	var x := 24.0
	var y := vp.y - 34.0
	if GameState.touch_mode:
		# En tactile, le bas gauche appartient au stick de marche.
		x = vp.x * 0.5 - 160.0
	_bar(Rect2(x, y - 50, 320, 20), mech.hp / mech.max_hp,
		Color(0.85, 0.25, 0.3), "BLINDAGE  %d / %d" % [ceili(maxf(mech.hp, 0.0)), int(mech.max_hp)])
	if mech.shield_max > 0.0:
		_bar(Rect2(x, y - 24, 320, 14), mech.shield / mech.shield_max, Color(0.35, 0.7, 1.0),
			"BOUCLIER  %d" % int(mech.shield))
	_bar(Rect2(x, y - 4, 320, 10), mech.stamina / mech.max_stamina, Color(0.35, 0.8, 0.5), "")
	if mech.burn_time > 0.0:
		_text(Vector2(x + 330, y - 34), "EN FEU", 18, Color(1.0, 0.55, 0.15))

## Compétences actives (v2 : `skill_bar.gd`) : icône, touche, voile de
## recharge qui descend, cadre doré quand elle est prête.
func _draw_skills(origin: Vector2, mech: Mech) -> void:
	var slots := [["speed", "MAJ", mech.dash_cd / Mech.DASH_COOLDOWN, mech.can_dash(), mech.dash_cd]]
	if mech.aoe_unlocked:
		slots.append(["aoe", "F", mech.aoe_cd / Mech.AOE_COOLDOWN, mech.aoe_cd <= 0.0, mech.aoe_cd])
	for i in slots.size():
		var s: Array = slots[i]
		var r := Rect2(origin + Vector2(i * (SLOT + 10), 0), Vector2(SLOT, SLOT))
		draw_rect(r, Color(0.08, 0.1, 0.14, 0.85))
		_icon(str(s[0]), r.grow(-10))
		var cd := clampf(float(s[2]), 0.0, 1.0)
		if cd > 0.0:
			var h := SLOT * cd
			draw_rect(Rect2(r.position.x, r.end.y - h, SLOT, h), Color(0.02, 0.03, 0.05, 0.7))
			_text(r.position + Vector2(14, 36), "%.1f" % float(s[4]), 18, Color.WHITE)
		elif not s[3]:
			draw_rect(r, Color(0.02, 0.03, 0.05, 0.45))
		draw_rect(r, Color(0.85, 0.72, 0.35) if s[3] else Color(0.3, 0.34, 0.42), false, 2.0)
		_text(r.position + Vector2(4, SLOT + 15), str(s[1]), 12, Color(0.82, 0.78, 0.66))

## Icône d'un pouvoir, découpée dans `ui_upgrades.png` (rang du pouvoir dans
## `UpgradeManager.ALL`, comme dans la v2).
func _icon(id: String, r: Rect2) -> void:
	if _icons == null:
		return
	var i := UpgradeManager.index_of(id)
	draw_texture_rect_region(_icons, r, Rect2(i * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE))

func _draw_radar(center: Vector2) -> void:
	draw_circle(center, RADAR_SIZE + 3, Color(0, 0, 0, 0.55))
	draw_circle(center, RADAR_SIZE, Color(0.05, 0.12, 0.1, 0.75))
	draw_arc(center, RADAR_SIZE * 0.5, 0, TAU, 40, Color(0.3, 1, 0.6, 0.18), 1.0)
	draw_arc(center, RADAR_SIZE, 0, TAU, 48, Color(0.3, 1, 0.6, 0.5), 1.5)
	var half_fov := deg_to_rad(38.0)
	for s in [-1.0, 1.0]:
		var d := Vector2(sin(half_fov * s), -cos(half_fov * s))
		draw_line(center, center + d * RADAR_SIZE, Color(0.3, 1, 0.6, 0.25), 1.0)
	var cam: CameraRig = game.camera
	var fwd := cam.forward_flat()
	var right := cam.right_flat()
	var me: Vector3 = game.mech.position
	var k := RADAR_SIZE / RADAR_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not e.alive:
			continue
		var v: Vector3 = e.position - me
		var p := Vector2(v.dot(right), -v.dot(fwd)) * k
		var behind := v.dot(fwd) < 0.0
		var r := clampf(e.radius * 3.0, 2.5, 6.0)
		if p.length() > RADAR_SIZE - 4:
			p = p.normalized() * (RADAR_SIZE - 4)
			r = 2.0
		var col := Color(1, 0.3, 0.2) if behind else Color(1, 0.75, 0.3)
		if e is Shade and e.is_damage_immune():
			col.a = 0.4
		draw_circle(center + p, r, col)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -6), center + Vector2(4, 4),
		center + Vector2(-4, 4)]), Color(0.5, 1, 1))

func _draw_touch(vp: Vector2, mech: Mech) -> void:
	if game.touch_stick_active:
		var o: Vector2 = game.touch_stick_origin
		draw_arc(o, 70, 0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(o + game.touch_stick_vec * 70.0, 26, Color(1, 1, 1, 0.3))
	else:
		_text(Vector2(30, vp.y - 80), "← glisser pour marcher", 16, Color(1, 1, 1, 0.45))
	_touch_button(game.dash_button_center(), "DASH", mech.can_dash(), Color(0.3, 0.8, 1.0))
	if mech.aoe_unlocked:
		_touch_button(game.wave_button_center(), "ONDE", mech.aoe_cd <= 0.0, Color(0.45, 0.85, 1.0))

func _touch_button(c: Vector2, label: String, ready: bool, col: Color) -> void:
	var r: float = game.TOUCH_BUTTON_R
	draw_circle(c, r, Color(col, 0.16 + (0.3 if ready else 0.0)))
	draw_arc(c, r, 0, TAU, 32, Color(col, 0.7 if ready else 0.3), 2.0)
	_text(c + Vector2(-22, 6), label, 17, Color(1, 1, 1, 0.85 if ready else 0.4))
