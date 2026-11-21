class_name Skeleton
extends Enemy
## Squelette archer : s'approche jusqu'à portée puis décoche des flèches
## (v2 : portée 260 px, une flèche de 4 dégâts toutes les 2 s). En 3D, il ne
## s'arrête à portée que s'il voit le mech : sans quoi il tirerait dans un mur.

const RANGE := 260.0 * Units.PX
const SHOT_INTERVAL := 2.0
const ARROW_DAMAGE := 4.0

var _shot_cd := 1.0
var _bow: Node3D
var _draw := 0.0

func _build_body() -> void:
	_build_bones(Color(0.85, 0.86, 0.8), Color(1.0, 0.25, 0.15))

## Silhouette d'os, partagée avec le squelette de feu.
func _build_bones(bone_color: Color, eye_color: Color) -> void:
	var s := model_scale()
	height = 2.0 * s
	_body.scale = Vector3.ONE * s
	var bone := skin(bone_color, 0.0, 0.7)
	var dark := Shapes.mat(bone_color.darkened(0.7))
	for side in [-1.0, 1.0]:
		var hip := Shapes.pivot(_body, Vector3(0.15 * side, 0.95, 0))
		Shapes.box(hip, Vector3(0.09, 0.9, 0.09), Vector3(0, -0.45, 0), bone)
		Shapes.box(hip, Vector3(0.14, 0.1, 0.28), Vector3(0, -0.9, -0.06), bone)
		_legs.append(hip)
	Shapes.box(_body, Vector3(0.42, 0.12, 0.2), Vector3(0, 0.98, 0), bone)  # bassin
	Shapes.box(_body, Vector3(0.07, 0.55, 0.07), Vector3(0, 1.25, 0.05), bone)  # colonne
	for i in 4:
		Shapes.box(_body, Vector3(0.46 - i * 0.05, 0.05, 0.26), Vector3(0, 1.32 + i * 0.1, -0.02), bone)
	Shapes.box(_body, Vector3(0.6, 0.08, 0.12), Vector3(0, 1.66, 0.02), bone)  # épaules
	Shapes.box(_body, Vector3(0.32, 0.34, 0.34), Vector3(0, 1.9, -0.02), bone)
	Shapes.box(_body, Vector3(0.24, 0.08, 0.1), Vector3(0, 1.74, -0.16), bone)
	var eye := Shapes.glow_mat(eye_color, 3.0)
	Shapes.box(_body, Vector3(0.08, 0.08, 0.04), Vector3(-0.08, 1.93, -0.2), eye)
	Shapes.box(_body, Vector3(0.08, 0.08, 0.04), Vector3(0.08, 1.93, -0.2), eye)
	Shapes.box(_body, Vector3(0.14, 0.06, 0.04), Vector3(0, 1.82, -0.2), dark)
	# Bras gauche tendu qui tient l'arc, bras droit qui tire la corde.
	Shapes.box(_body, Vector3(0.07, 0.07, 0.6), Vector3(-0.3, 1.6, -0.3), bone)
	Shapes.box(_body, Vector3(0.07, 0.07, 0.45), Vector3(0.28, 1.6, -0.15), bone)
	_bow = Shapes.pivot(_body, Vector3(-0.3, 1.6, -0.62))
	var wood := Shapes.mat(Color(0.3, 0.2, 0.1))
	for k in [-1.0, 1.0]:
		var limb := Shapes.box(_bow, Vector3(0.05, 0.55, 0.05), Vector3(0, 0.27 * k, 0.08), wood)
		limb.rotation.x = 0.35 * k
	Shapes.box(_bow, Vector3(0.015, 0.95, 0.015), Vector3(0, 0, 0.2), Shapes.mat(Color(0.8, 0.8, 0.7)))

func _behaviour(delta: float) -> void:
	var dist := distance_to_mech()
	var sees := sees_mech()
	if dist > RANGE or not sees:
		_chase(delta)
	elif dist < RANGE * 0.6:
		_chase(delta, -0.6)
	else:
		_hold(delta)
	_shot_cd -= delta
	_draw = maxf(0.0, _draw - delta * 3.0)
	if _shot_cd <= 0.0 and dist <= RANGE and sees:
		_shot_cd = SHOT_INTERVAL
		_draw = 1.0
		_shoot()

func _shoot() -> void:
	shoot(300.0, ARROW_DAMAGE, 5.0, Color(0.85, 0.86, 0.8), "arrow")

func _animate(delta: float) -> void:
	super(delta)
	if _bow != null:
		_bow.rotation.z = _draw * 0.2
