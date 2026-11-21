class_name Risen
extends Enemy
## Revenant : sort de terre. Pendant l'émergence il est immobile, ne blesse
## pas et ne prend aucun dégât (v2 : 20 frames). En 3D, on le voit monter du
## sol dans une gerbe de terre ; l'émergence est un peu plus longue pour que
## ça se voie.

const EMERGE_TIME := 0.6

var _emerging := EMERGE_TIME

func _build_body() -> void:
	var s := model_scale()
	height = 2.1 * s
	_body.scale = Vector3.ONE * s
	var flesh := skin(color.lightened(0.1))
	var shroud := skin(Color(0.2, 0.17, 0.15), 0.0, 1.0)
	for side in [-1.0, 1.0]:
		var hip := Shapes.pivot(_body, Vector3(0.2 * side, 0.95, 0))
		Shapes.box(hip, Vector3(0.28, 0.95, 0.3), Vector3(0, -0.47, 0), shroud)
		_legs.append(hip)
	var trunk := Shapes.pivot(_body, Vector3(0, 0.95, 0))
	trunk.rotation.x = -0.12
	Shapes.box(trunk, Vector3(0.75, 0.85, 0.42), Vector3(0, 0.42, 0), shroud)
	# Linceul en lambeaux qui pend devant et derrière.
	Shapes.box(trunk, Vector3(0.7, 0.6, 0.05), Vector3(0, -0.1, -0.22), shroud)
	Shapes.box(trunk, Vector3(0.6, 0.7, 0.05), Vector3(0, -0.15, 0.22), shroud)
	Shapes.box(trunk, Vector3(0.44, 0.46, 0.44), Vector3(0, 1.05, -0.02), flesh)
	Shapes.box(trunk, Vector3(0.5, 0.2, 0.5), Vector3(0, 1.3, 0.02), shroud)  # capuche
	var eye := Shapes.glow_mat(Color(0.3, 1.0, 0.5), 2.8)
	Shapes.box(trunk, Vector3(0.1, 0.06, 0.04), Vector3(-0.11, 1.08, -0.25), eye)
	Shapes.box(trunk, Vector3(0.1, 0.06, 0.04), Vector3(0.11, 1.08, -0.25), eye)
	for side in [-1.0, 1.0]:
		var arm := Shapes.box(trunk, Vector3(0.2, 0.8, 0.2), Vector3(0.48 * side, 0.4, -0.1), flesh)
		arm.rotation.x = -0.5
		Shapes.box(arm, Vector3(0.24, 0.12, 0.3), Vector3(0, -0.42, -0.08), flesh)  # griffes

func _on_spawn() -> void:
	immune = true
	_body.position.y = -height
	Shapes.burst(get_parent(), position + Vector3(0, 0.3, 0), Color(0.25, 0.18, 0.12), 16, 5.0, 0.2)

func _behaviour(delta: float) -> void:
	if _emerging > 0.0:
		_emerging -= delta
		_body.position.y = -height * maxf(0.0, _emerging / EMERGE_TIME)
		if _emerging <= 0.0:
			immune = false
			_body.position.y = 0.0
		_face(mech_flat() - flat(), delta)
		return
	_chase(delta)

func _deals_no_contact_damage() -> bool:
	return _emerging > 0.0
