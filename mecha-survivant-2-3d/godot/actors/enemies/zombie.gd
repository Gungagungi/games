class_name Zombie
extends Enemy
## Le mort-vivant de base : lent, encaisse, fonce droit sur le mech. Voûté,
## bras tendus, démarche chaloupée.

func _build_body() -> void:
	var s := model_scale()
	height = 2.0 * s
	_body.scale = Vector3.ONE * s
	var flesh := skin(color)
	var rag := skin(color.darkened(0.5), 0.0, 1.0)
	for side in [-1.0, 1.0]:
		var hip := Shapes.pivot(_body, Vector3(0.2 * side, 0.95, 0))
		Shapes.box(hip, Vector3(0.26, 0.95, 0.28), Vector3(0, -0.47, 0), rag)
		_legs.append(hip)
	var trunk := Shapes.pivot(_body, Vector3(0, 0.95, 0))
	trunk.rotation.x = -0.28
	Shapes.box(trunk, Vector3(0.65, 0.75, 0.36), Vector3(0, 0.4, 0), rag)
	Shapes.box(trunk, Vector3(0.3, 0.2, 0.05), Vector3(0.1, 0.45, -0.19), flesh)  # chair à vif
	Shapes.box(trunk, Vector3(0.42, 0.42, 0.42), Vector3(0, 0.98, -0.06), flesh)
	Shapes.box(trunk, Vector3(0.3, 0.1, 0.1), Vector3(0, 0.82, -0.26), Shapes.mat(Color(0.12, 0.05, 0.04)))  # mâchoire
	var eye := Shapes.glow_mat(Color(1.0, 0.85, 0.2), 2.5)
	Shapes.box(trunk, Vector3(0.09, 0.07, 0.04), Vector3(-0.1, 1.02, -0.28), eye)
	Shapes.box(trunk, Vector3(0.09, 0.07, 0.04), Vector3(0.1, 1.02, -0.28), eye)
	for side in [-1.0, 1.0]:
		var arm := Shapes.box(trunk, Vector3(0.18, 0.18, 0.8), Vector3(0.42 * side, 0.65, -0.38), flesh)
		arm.rotation.x = 0.2

func _on_spawn() -> void:
	if randf() < 0.25:
		AudioManager.sfx("enemy_groan", -12.0)

func _animate(delta: float) -> void:
	super(delta)
	_body.rotation.z = sin(_phase * 0.5) * 0.08
