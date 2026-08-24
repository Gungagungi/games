class_name Bullet
extends Area2D
## Projectile du joueur. Construit en code (pas de .tscn) : une seule forme,
## instanciée souvent, rien à configurer visuellement.

const SPEED := 420.0   # v1 : 7 px/frame
const LIFETIME := 2.0

var direction := Vector2.RIGHT
var damage := 12.0
var _life := LIFETIME

func setup(from: Vector2, dir: Vector2, dmg: float) -> void:
	position = from
	direction = dir
	damage = dmg

func _ready() -> void:
	collision_layer = 4      # player_bullets
	collision_mask = 2       # enemies
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	var visual := SpriteOrShape.new()
	visual.texture_name = "proj_bullet"
	visual.radius = 4.0
	visual.shape_color = Color(1.0, 0.86, 0.45)
	add_child(visual)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_life -= delta
	if _life <= 0.0 or not get_viewport_rect().grow(40.0).has_point(position):
		queue_free()

func _on_body_entered(body: Node) -> void:
	_hit(body)

func _on_area_entered(area: Node) -> void:
	_hit(area)

func _hit(node: Node) -> void:
	var enemy := node as EnemyBase
	if enemy == null:
		return
	if enemy.is_damage_immune():
		return
	enemy.take_damage(damage)
	queue_free()
