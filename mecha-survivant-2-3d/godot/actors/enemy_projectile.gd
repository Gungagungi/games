class_name EnemyProjectile
extends Node3D
## Projectile ennemi : flèche, flèche enflammée, boule de feu (v2 :
## `enemy_projectile.gd`). Vole en ligne droite vers où était le mech, meurt
## sur un mur, et embrase le mech à l'impact si `ignite_dps` > 0.

var direction := Vector3.FORWARD
var speed := 18.0
var damage := 5.0
var radius := 0.3
var color := Color.WHITE
var kind := "arrow"
var ignite_dps := 0.0
var ignite_duration := 0.0
var impact_sfx := ""
var life := 5.0

func setup(from: Vector3, dir: Vector3, spd: float, dmg: float, r: float, col: Color, k: String) -> void:
	position = from
	direction = dir
	speed = spd
	damage = dmg
	radius = r
	color = col
	kind = k

func _ready() -> void:
	if kind == "arrow":
		var shaft := Shapes.box(self, Vector3(0.05, 0.05, 1.0), Vector3.ZERO, Shapes.mat(Color(0.45, 0.35, 0.22)))
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Shapes.box(self, Vector3(0.12, 0.12, 0.18), Vector3(0, 0, -0.5), Shapes.mat(color, 0.5, 0.4))
	else:
		# Boule de feu ou flèche enflammée : cœur lumineux et traînée.
		var core := Shapes.sphere(self, maxf(radius, 0.18), Vector3.ZERO, Shapes.glow_mat(color, 3.0), 8)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not GameState.smoke_test:
			var trail := Shapes.flames(self, Vector3.ZERO, radius * 0.6, 10, color)
			trail.direction = Vector3.ZERO
			trail.gravity = Vector3(0, 0.8, 0)
			trail.initial_velocity_max = 0.6
	look_at(position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)

func _process(delta: float) -> void:
	if not GameState.running:
		return
	var from := position
	var to := from + direction * speed * delta
	life -= delta
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech != null and mech.alive:
		var c := mech.center()
		var closest := Geometry3D.get_closest_point_to_segment(c, from, to)
		var reach := radius + Mech.RADIUS
		# Le mech est une capsule : on mesure à plat, et la hauteur à part.
		if Vector2(closest.x - c.x, closest.z - c.z).length() < reach and closest.y < Mech.HEIGHT + radius:
			_hit(mech)
			return
	if life <= 0.0 or (Village.current != null and Village.current.segment_hit(from, to, 0.35) != null):
		if kind != "arrow":
			Shapes.burst(get_parent(), position, color, 8, 4.0, 0.12, true)
		queue_free()
		return
	position = to

func _hit(mech: Mech) -> void:
	# L'embrasement d'abord : le coup donne au mech un instant
	# d'invulnérabilité, qui empêcherait sinon l'embrasement de prendre.
	if ignite_dps > 0.0:
		mech.ignite(ignite_dps, ignite_duration)
	mech.take_damage(damage)
	if impact_sfx != "":
		AudioManager.sfx(impact_sfx, -4.0)
	if kind != "arrow":
		Shapes.burst(get_parent(), position, color, 12, 5.0, 0.14, true)
	queue_free()
