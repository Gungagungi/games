extends Node3D
# Un mort-vivant. Trois variantes, toutes construites en boîtes : le marcheur,
# le coureur (petit, rapide, fragile) et la brute (grosse, lente, qui cogne).
# Le déplacement et les dégâts au contact sont gérés ici ; les collisions avec
# les obstacles et entre ennemis par main.gd.

const Shapes := preload("res://scenes/shapes.gd")

const TYPES := {
	"walker": {"hp": 30.0, "speed": 3.4, "damage": 10.0, "scale": 1.0, "color": Color(0.36, 0.46, 0.31)},
	"runner": {"hp": 14.0, "speed": 6.8, "damage": 6.0, "scale": 0.78, "color": Color(0.52, 0.38, 0.3)},
	"brute": {"hp": 140.0, "speed": 2.2, "damage": 25.0, "scale": 1.9, "color": Color(0.32, 0.33, 0.42)},
}
const ATTACK_INTERVAL := 0.9

var kind := "walker"
var hp := 30.0
var max_hp := 30.0
var speed := 3.4
var damage := 10.0
var radius := 0.7
var height := 2.0
var dead := false

var _mats: Array[StandardMaterial3D] = []
var _legs: Array[Node3D] = []
var _body: Node3D
var _phase := 0.0
var _attack_cd := 0.0
var _flash := 0.0
var _rise := 0.0  # sortie de terre à l'apparition


func setup(type_name: String, hp_mult: float) -> void:
	kind = type_name
	var t: Dictionary = TYPES[type_name]
	max_hp = t.hp * hp_mult
	hp = max_hp
	speed = t.speed * randf_range(0.9, 1.1)
	damage = t.damage
	var s: float = t.scale
	radius = 0.7 * s
	height = 2.0 * s
	_phase = randf() * TAU
	_build(t.color, s)


func _build(color: Color, s: float) -> void:
	var skin := Shapes.mat(color, 0.0, 0.9)
	var rag := Shapes.mat(color.darkened(0.45), 0.0, 1.0)
	_mats = [skin, rag]
	_body = Shapes.pivot(self, Vector3.ZERO)
	_body.scale = Vector3.ONE * s
	for side in [-1.0, 1.0]:
		var hip := Shapes.pivot(_body, Vector3(0.2 * side, 0.95, 0))
		Shapes.box(hip, Vector3(0.26, 0.95, 0.28), Vector3(0, -0.47, 0), rag)
		_legs.append(hip)
	var trunk := Shapes.pivot(_body, Vector3(0, 0.95, 0))
	trunk.rotation.x = -0.25  # voûté vers l'avant
	Shapes.box(trunk, Vector3(0.65, 0.75, 0.36), Vector3(0, 0.4, 0), rag)
	Shapes.box(trunk, Vector3(0.42, 0.42, 0.42), Vector3(0, 0.98, -0.06), skin)
	var eye := Shapes.glow_mat(Color(1.0, 0.15, 0.05), 3.0)
	Shapes.box(trunk, Vector3(0.09, 0.07, 0.04), Vector3(-0.1, 1.02, -0.28), eye)
	Shapes.box(trunk, Vector3(0.09, 0.07, 0.04), Vector3(0.1, 1.02, -0.28), eye)
	for side in [-1.0, 1.0]:
		var arm := Shapes.box(trunk, Vector3(0.18, 0.18, 0.75), Vector3(0.42 * side, 0.65, -0.35), skin)
		arm.rotation.x = 0.2


func is_alive() -> bool:
	return not dead


# Avance vers le mech et frappe au contact. Renvoie les dégâts infligés cette
# frame (0 le plus souvent).
func step(delta: float, target: Vector3, push: Vector3) -> float:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	for m in _mats:
		m.emission_enabled = _flash > 0.0
		m.emission = Color(1, 1, 1) * _flash * 0.8
	if _rise < 1.0:
		_rise = minf(_rise + delta * 1.6, 1.0)
		_body.position.y = (_rise - 1.0) * height
		return 0.0
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var reach := radius + 1.3
	var motion := Vector3.ZERO
	if dist > reach * 0.8:
		motion = dir * speed * delta
	motion += push * delta
	position += motion
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
	_phase += delta * speed * 2.2
	var swing := sin(_phase) * 0.6
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_body.rotation.z = sin(_phase * 0.5) * 0.08  # démarche chaloupée
	if dist < reach and _attack_cd <= 0.0:
		_attack_cd = ATTACK_INTERVAL
		return damage
	return 0.0


func hit(amount: float) -> bool:
	if dead:
		return false
	hp -= amount
	_flash = 1.0
	if hp <= 0.0:
		dead = true
	return dead


func body_color() -> Color:
	return _mats[0].albedo_color
