class_name EnemyBase
extends Area2D
## Base commune à tous les ennemis et boss.
##
## Remplace le `switch (e.type)` de la v1 : chaque variante surcharge
## `_behaviour()` pour son déplacement et ses attaques. `is_damage_immune()`
## est le point de passage unique de toute immunité (déphasage des ombres,
## bouclier du méga-boss, invulnérabilité ultime du Titan) — **toute** source
## de dégâts doit l'interroger.

const CONTACT_INTERVAL := 0.5

var type_id := "zombie"
var max_hp := 30.0
var hp := 30.0
var speed := 39.0
var damage := 8.0
var radius := 15.0
var is_boss := false
var xp_color := Color(0.42, 0.62, 0.35)

var immune := false          ## immunité explicite (bouclier, phase d'ultime)
var alive := true

var _contact_cd := 0.0
var _visual: SpriteOrShape
var _collision: CollisionShape2D

var player: Player = null

func configure(stats: Dictionary) -> void:
	type_id = stats.get("type", type_id)
	max_hp = stats.get("max_hp", max_hp)
	hp = max_hp
	speed = stats.get("speed", speed)
	damage = stats.get("damage", damage)
	radius = stats.get("radius", radius)
	xp_color = stats.get("color", xp_color)

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	_collision = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_collision.shape = circle
	add_child(_collision)
	_visual = SpriteOrShape.new()
	_visual.texture_name = _sprite_name()
	_visual.frame_count = 4
	_visual.radius = radius
	_visual.shape_color = xp_color
	_visual.shape = _shape_kind()
	add_child(_visual)
	player = get_tree().get_first_node_in_group("player") as Player
	_on_spawn()

func _sprite_name() -> String:
	return "enemy_%s" % type_id

func _shape_kind() -> String:
	return "circle"

func _on_spawn() -> void:
	pass

func _process(delta: float) -> void:
	if not alive or not GameState.running:
		return
	if player == null or not player.alive:
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_behaviour(delta)
	_check_contact()

## Comportement par défaut : foncer sur le joueur.
func _behaviour(delta: float) -> void:
	_chase(delta)

func _chase(delta: float, factor: float = 1.0) -> void:
	var dir := (player.global_position - global_position).normalized()
	global_position += dir * speed * factor * delta

func _check_contact() -> void:
	if _contact_cd > 0.0 or _deals_no_contact_damage():
		return
	if global_position.distance_to(player.global_position) <= radius + 16.0:
		player.take_damage(damage)
		_contact_cd = CONTACT_INTERVAL

func _deals_no_contact_damage() -> bool:
	return false

## Point de passage unique de l'immunité. Voir l'en-tête de ce fichier.
func is_damage_immune() -> bool:
	return immune or not alive

func take_damage(amount: float) -> void:
	if is_damage_immune():
		return
	hp -= amount
	_visual.flash()
	AudioManager.sfx("boss_hurt" if is_boss else "hit_enemy")
	EventBus.float_text_requested.emit(
		global_position + Vector2(0, -radius), str(int(amount)), Color(1.0, 0.9, 0.5))
	if is_boss:
		EventBus.boss_hp_changed.emit(clampf(hp / max_hp, 0.0, 1.0))
	if hp <= 0.0:
		_on_hp_depleted()

## Surchargé par les boss multi-phases : la barre repart à plein tant qu'il
## reste une phase.
func _on_hp_depleted() -> void:
	die()

func die() -> void:
	if not alive:
		return
	alive = false
	AudioManager.sfx("boss_death" if is_boss else "enemy_death")
	EventBus.enemy_died.emit(global_position, is_boss)
	if is_boss:
		EventBus.boss_defeated.emit()
	queue_free()
