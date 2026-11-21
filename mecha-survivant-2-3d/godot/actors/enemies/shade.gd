class_name Shade
extends Enemy
## Créature de l'ombre : rapide, alterne des phases intangibles où les balles
## la traversent et où elle ne blesse pas (v2 : 1,6 s solide, 1,1 s déphasée).
## Spectre flottant sans jambes, qui devient presque transparent déphasé.

const SOLID_TIME := 1.6
const PHASED_TIME := 1.1

var _phased := false
var _timer := SOLID_TIME
var _ghost: Array[StandardMaterial3D] = []
var _float: Node3D

func _build_body() -> void:
	var s := model_scale()
	height = 2.1 * s
	_body.scale = Vector3.ONE * s
	_float = Shapes.pivot(_body, Vector3.ZERO)
	var cloak := _ghost_mat(color)
	var dark := _ghost_mat(color.darkened(0.6))
	# Robe en cônes empilés, qui s'effile vers le sol.
	var robe := Shapes.cylinder(_float, 0.08, 1.1, Vector3(0, 0.75, 0), cloak, 8, 0.42)
	robe.rotation.x = 0.0
	Shapes.cylinder(_float, 0.45, 0.6, Vector3(0, 1.55, 0), dark, 8, 0.3)
	Shapes.sphere(_float, 0.3, Vector3(0, 1.95, 0), dark, 10)
	var eye := Shapes.glow_mat(Color(0.85, 0.6, 1.0), 3.0)
	Shapes.box(_float, Vector3(0.09, 0.05, 0.04), Vector3(-0.1, 1.97, -0.27), eye)
	Shapes.box(_float, Vector3(0.09, 0.05, 0.04), Vector3(0.1, 1.97, -0.27), eye)
	for side in [-1.0, 1.0]:
		var arm := Shapes.cylinder(_float, 0.03, 0.9, Vector3(0.42 * side, 1.4, -0.3), cloak, 6, 0.12)
		arm.rotation.x = -1.1

func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := Shapes.ghost_mat(Color(c, 0.9))
	_mats.append(m)
	_ghost.append(m)
	return m

func _behaviour(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_phased = not _phased
		_timer = PHASED_TIME if _phased else SOLID_TIME
		for m in _ghost:
			m.albedo_color.a = 0.18 if _phased else 0.9
		AudioManager.sfx("shade_phase", -10.0)
	_chase(delta)

func _animate(delta: float) -> void:
	_phase += delta * 3.0
	_float.position.y = 0.35 + sin(_phase) * 0.12
	_float.rotation.x = -0.25

func is_damage_immune() -> bool:
	return _phased or super()

func _deals_no_contact_damage() -> bool:
	return _phased
