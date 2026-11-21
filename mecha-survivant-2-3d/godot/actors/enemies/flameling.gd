class_name Flameling
extends Enemy
## Mob de feu (v2 : `flameling.gd`) : garde ses distances et lance une boule
## de feu toutes les 3 s, incantation de 0,6 s comprise, pendant laquelle il
## gonfle. Les dégâts valent 5 % des PV max du mech, recalculés au tir.

const SHOT_INTERVAL := 3.0
const WINDUP := 0.6
const KEEP_DISTANCE := 240.0 * Units.PX

var _shot_cd := SHOT_INTERVAL
var _winding := 0.0
var _core: Node3D

func _build_body() -> void:
	var s := model_scale()
	height = 1.5 * s
	_body.scale = Vector3.ONE * s
	_core = Shapes.pivot(_body, Vector3(0, 0.85, 0))
	var ember := skin(Color(0.35, 0.12, 0.05), 0.0, 0.8)
	Shapes.sphere(_core, 0.42, Vector3.ZERO, ember, 10)
	Shapes.sphere(_core, 0.3, Vector3(0, 0.05, -0.18), Shapes.glow_mat(color, 3.2), 10)
	var eye := Shapes.glow_mat(Color(1.0, 0.95, 0.6), 4.0)
	Shapes.box(_core, Vector3(0.08, 0.08, 0.04), Vector3(-0.1, 0.12, -0.43), eye)
	Shapes.box(_core, Vector3(0.08, 0.08, 0.04), Vector3(0.1, 0.12, -0.43), eye)
	for side in [-1.0, 1.0]:
		Shapes.sphere(_core, 0.14, Vector3(0.45 * side, -0.1, -0.1), ember, 6)
	if not GameState.smoke_test:
		# Pas de lumière propre : une horde de flamelings multiplierait les
		# passes d'éclairage du rendu Compatibility.
		Shapes.flames(_core, Vector3(0, 0.25, 0), 0.32, 18, color)

func _behaviour(delta: float) -> void:
	var dist := distance_to_mech()
	if _winding > 0.0:
		_winding -= delta
		_core.scale = Vector3.ONE * (1.0 + 0.3 * (1.0 - _winding / WINDUP))
		_face(mech_flat() - flat(), delta)
		if _winding <= 0.0:
			_core.scale = Vector3.ONE
			_cast()
		return
	if dist > KEEP_DISTANCE * 1.2 or not sees_mech():
		_chase(delta)
	elif dist < KEEP_DISTANCE * 0.8:
		_chase(delta, -0.8)
	else:
		_hold(delta)
	_shot_cd -= delta
	if _shot_cd <= 0.0 and sees_mech():
		_shot_cd = SHOT_INTERVAL
		_winding = WINDUP
		AudioManager.sfx("flameling_cast", -8.0)

func _cast() -> void:
	var ball := shoot(220.0, mech.max_hp * 0.05, 10.0, Color(0.98, 0.55, 0.18), "fireball")
	ball.impact_sfx = "fireball_impact"

func _animate(delta: float) -> void:
	_phase += delta * 4.0
	_core.position.y = 0.85 + sin(_phase) * 0.1
