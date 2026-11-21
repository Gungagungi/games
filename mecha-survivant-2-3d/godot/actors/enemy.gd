class_name Enemy
extends Node3D
## Base commune des ennemis, reprise de `mecha-survivant-2/godot/scenes/
## enemies/enemy_base.gd` : chaque variante surcharge `_behaviour()` pour ses
## déplacements et ses attaques, et `_build_body()` pour sa silhouette.
##
## `is_damage_immune()` reste le **point de passage unique** de toute
## immunité (déphasage des ombres, émergence des revenants) : toute source
## de dégâts doit l'interroger.

const CONTACT_INTERVAL := 0.5
## Portée du coup au contact au-delà des deux rayons (v2 : 16 px).
const CONTACT_REACH := 16.0 * Units.PX
## Rayon de collision contre les murs, plafonné (v2 : 12 px) : un zombie de
## haut tier doit encore passer une porte de deux cases.
const WALL_RADIUS := 12.0 * Units.PX

var type_id := "zombie"
var max_hp := 30.0
var hp := 30.0
var speed := 2.4
var damage := 8.0
var radius := 0.9
var color := Color(0.42, 0.62, 0.35)
## Hauteur du corps : le tir le touche sur toute cette hauteur.
var height := 2.0
var immune := false
var alive := true
## Poussée de séparation calculée par `main.gd` (la horde ne se fond pas en
## un seul point).
var push := Vector3.ZERO

var mech: Mech
var _contact_cd := 0.0
var _flash := 0.0
var _mats: Array[StandardMaterial3D] = []
var _body: Node3D
var _legs: Array[Node3D] = []
var _phase := 0.0

func configure(stats: Dictionary) -> void:
	type_id = stats.get("type", type_id)
	max_hp = stats.get("max_hp", max_hp)
	hp = max_hp
	speed = stats.get("speed", speed)
	damage = stats.get("damage", damage)
	radius = stats.get("radius", radius)
	color = stats.get("color", color)

func _ready() -> void:
	add_to_group("enemies")
	_phase = randf() * TAU
	_body = Shapes.pivot(self, Vector3.ZERO)
	_build_body()
	_on_spawn()

## Échelle du modèle : les silhouettes sont dessinées pour un rayon de 0,8 m.
func model_scale() -> float:
	return radius / 0.8

func _build_body() -> void:
	pass

func _on_spawn() -> void:
	pass

## Matériau du corps, enregistré pour le flash des coups reçus.
func skin(c: Color, metallic := 0.0, roughness := 0.9) -> StandardMaterial3D:
	var m := Shapes.mat(c, metallic, roughness)
	_mats.append(m)
	return m

func _process(delta: float) -> void:
	if not alive or not GameState.running or mech == null or not mech.alive:
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	for m in _mats:
		m.emission_enabled = _flash > 0.0
		m.emission = Color(1, 1, 1) * _flash * 0.8
	_behaviour(delta)
	_animate(delta)
	_check_contact()

## Par défaut : foncer sur le mech.
func _behaviour(delta: float) -> void:
	_chase(delta)

func flat() -> Vector2:
	return Vector2(position.x, position.z)

func mech_flat() -> Vector2:
	return Vector2(mech.position.x, mech.position.z)

func distance_to_mech() -> float:
	return flat().distance_to(mech_flat())

## Le mech est-il visible d'ici, sans mur entre nous ?
func sees_mech() -> bool:
	return Village.current == null or Village.current.line_clear(flat(), mech_flat())

## Poursuite (factor > 0) ou repli (factor < 0). La poursuite suit le champ
## de distances du village — par les portes, autour des murs — et le
## déplacement glisse sur les cases pleines (v2).
func _chase(delta: float, factor: float = 1.0) -> void:
	var v := Village.current
	var here := flat()
	var dir: Vector2
	if v == null:
		dir = (mech_flat() - here).normalized()
	elif factor >= 0.0:
		dir = v.flow_dir(here, mech_flat())
	else:
		dir = (mech_flat() - here).normalized()
	var motion := dir * speed * factor * delta + Vector2(push.x, push.z) * delta
	var moved := here
	if v != null:
		moved = v.move_circle(here, motion, minf(radius, WALL_RADIUS))
	else:
		moved = here + motion
	position = Vector3(moved.x, position.y, moved.y)
	_face(mech_flat() - here, delta)

## Sur place : seulement la séparation (tireurs à portée).
func _hold(delta: float) -> void:
	var v := Village.current
	var here := flat()
	if v != null:
		var moved := v.move_circle(here, Vector2(push.x, push.z) * delta, minf(radius, WALL_RADIUS))
		position = Vector3(moved.x, position.y, moved.y)
	_face(mech_flat() - here, delta)

func _face(dir: Vector2, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.y), minf(1.0, delta * 8.0))

## Balancement de marche, commun aux silhouettes à jambes.
func _animate(delta: float) -> void:
	_phase += delta * speed * 2.2
	if _legs.size() >= 2:
		var swing := sin(_phase) * 0.6
		_legs[0].rotation.x = swing
		_legs[1].rotation.x = -swing

func _check_contact() -> void:
	if _contact_cd > 0.0 or _deals_no_contact_damage():
		return
	if distance_to_mech() <= radius + Mech.RADIUS + CONTACT_REACH:
		_on_contact()
		mech.take_damage(damage)
		_contact_cd = CONTACT_INTERVAL

## Juste avant le coup au contact (le squelette de feu y embrase le mech).
func _on_contact() -> void:
	pass

func _deals_no_contact_damage() -> bool:
	return false

func is_damage_immune() -> bool:
	return immune or not alive

## Point visé : le milieu du corps.
func aim_point() -> Vector3:
	return position + Vector3(0, height * 0.55, 0)

## Le segment [a, b] traverse-t-il le corps ? Le corps est une capsule
## verticale, du sol à `height`.
func segment_hits(a: Vector3, b: Vector3, extra := 0.0) -> bool:
	var bottom := position + Vector3(0, radius * 0.6, 0)
	var top := position + Vector3(0, maxf(height - radius * 0.6, radius * 0.6), 0)
	var pts := Geometry3D.get_closest_points_between_segments(a, b, bottom, top)
	var r := radius * 1.05 + extra
	return pts[0].distance_squared_to(pts[1]) < r * r

func take_damage(amount: float, at: Vector3) -> void:
	if is_damage_immune():
		return
	hp -= amount
	_flash = 1.0
	Shapes.burst(get_parent(), at, color.lightened(0.5), 5, 4.0, 0.1)
	AudioManager.sfx("hit_enemy", -12.0, 0.15)
	EventBus.float_text_requested.emit(position + Vector3(0, height + 0.4, 0), str(int(amount)),
		Color(1.0, 0.9, 0.5))
	if hp <= 0.0:
		die()

func die() -> void:
	if not alive:
		return
	alive = false
	AudioManager.sfx("enemy_death", -6.0, 0.15)
	EventBus.enemy_died.emit(position + Vector3(0, height * 0.5, 0), color, height)
	queue_free()

## Tir d'un projectile vers le centre du mech.
func shoot(speed_px: float, dmg: float, radius_px: float, col: Color, kind: String) -> EnemyProjectile:
	var from := position + Vector3(0, height * 0.65, 0)
	var dir := (mech.center() - from).normalized()
	var p := EnemyProjectile.new()
	p.setup(from + dir * (radius + 0.2), dir, speed_px * Units.PX, dmg, radius_px * Units.PX, col, kind)
	get_parent().add_child(p)
	return p
