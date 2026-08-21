class_name EnemyProjectile
extends Node2D
## Projectile ennemi générique : flèche, boule de feu, crachat empoisonné.
## Un `flag` optionnel marque le projectile ultime du Titan, qui suit un
## chemin de dégâts distinct (`take_ultimate_damage`).

var direction := Vector2.RIGHT
var speed := 300.0
var damage := 5.0
var radius := 5.0
var color := Color.WHITE
var ultimate := false
var poison := false
var life := 5.0

var _visual: SpriteOrShape

func setup(from: Vector2, dir: Vector2, spd: float, dmg: float, r: float,
		col: Color, sprite: String = "") -> void:
	position = from
	direction = dir
	speed = spd
	damage = dmg
	radius = r
	color = col
	set_meta("sprite", sprite)

func _ready() -> void:
	_visual = SpriteOrShape.new()
	_visual.texture_name = str(get_meta("sprite", ""))
	_visual.frame_count = 4 if ultimate else 1
	_visual.radius = radius
	_visual.shape_color = color
	add_child(_visual)

func _process(delta: float) -> void:
	if not GameState.running:
		return
	position += direction * speed * delta
	life -= delta
	if life <= 0.0 or not get_viewport_rect().grow(60.0).has_point(position):
		queue_free()
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.alive:
		return
	if position.distance_to(p.global_position) <= radius + 16.0:
		if ultimate:
			p.take_ultimate_damage()
		else:
			p.take_damage(damage)
		queue_free()
