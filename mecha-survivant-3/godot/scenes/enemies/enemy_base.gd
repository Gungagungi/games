class_name EnemyBase
extends Area2D
## Base commune à tous les ennemis et boss.
##
## Remplace le `switch (e.type)` de la v1 : chaque variante surcharge
## `_behaviour()` pour son déplacement et ses attaques. `is_damage_immune()`
## est le point de passage unique de toute immunité (déphasage des ombres,
## bouclier temporaire d'un boss en phase) — **toute** source de dégâts doit
## l'interroger.

const CONTACT_INTERVAL := 0.5
## Rayon de collision contre les murs, plafonné : un zombie de haut tier
## (rayon 30) doit encore passer une porte de deux cases.
const WALL_RADIUS := 12.0

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

## Poursuite (factor > 0) ou repli (factor < 0). Hors boss, le chemin suit le
## champ de distances du niveau — par les portes, autour des murs — et le
## déplacement glisse sur les cases pleines. Les boss vont tout droit et
## traversent les ruines.
func _chase(delta: float, factor: float = 1.0) -> void:
	var level := Level.current
	if is_boss or level == null:
		var straight := (player.global_position - global_position).normalized()
		global_position += straight * speed * factor * delta
		return
	var dir: Vector2
	if factor >= 0.0:
		dir = level.flow_dir(global_position, player.global_position)
	else:
		dir = (player.global_position - global_position).normalized()
	global_position = level.move_circle(global_position,
		dir * speed * factor * delta, minf(radius, WALL_RADIUS))

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
	_visual.squash(0.12 if is_boss else 0.22)
	_knockback()
	HitSpark.spawn(get_parent(), global_position, xp_color.lightened(0.5))
	AudioManager.sfx("boss_hurt" if is_boss else "hit_enemy")
	EventBus.float_text_requested.emit(
		global_position + Vector2(0, -radius), str(int(amount)), Color(1.0, 0.9, 0.5))
	if is_boss:
		EventBus.boss_hp_changed.emit(clampf(hp / max_hp, 0.0, 1.0))
	if hp <= 0.0:
		_on_hp_depleted()

## Léger recul à l'impact, à l'opposé du mech. Les boss encaissent sans
## broncher ; le recul glisse sur les murs comme la poursuite.
const KNOCKBACK := 5.0

func _knockback() -> void:
	if is_boss or player == null or Level.current == null:
		return
	var away := (global_position - player.global_position).normalized()
	global_position = Level.current.move_circle(global_position,
		away * KNOCKBACK, minf(radius, WALL_RADIUS))

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
	Juice.death_burst(get_parent(), global_position, xp_color,
		48 if is_boss else 12, 260.0 if is_boss else 140.0)
	if is_boss:
		Juice.hitstop(get_tree(), 0.18)
		EventBus.screen_shake_requested.emit(22.0)
		EventBus.boss_defeated.emit()
	_play_death_then_free()

## L'ennemi déroule ses cases de mort s'il en a, puis se désintègre
## (`entity.gdshader`) ; sans planche de mort, il se désintègre aussitôt. Dans
## les deux cas `alive` est déjà faux : il ne bouge plus, ne blesse plus et
## n'est plus compté par le gestionnaire de vagues. En smoke, rien à voir :
## il disparaît dans la frame, comme dans la v2.
const DISSOLVE_TIME := 0.35

func _play_death_then_free() -> void:
	if GameState.smoke_test:
		queue_free()
		return
	_collision.set_deferred("disabled", true)
	var duration := _visual.animation_duration("death")
	if duration > 0.0:
		_visual.play("death", false)
		await get_tree().create_timer(duration).timeout
	_visual.dissolve(DISSOLVE_TIME, xp_color.lightened(0.4))
	await get_tree().create_timer(DISSOLVE_TIME).timeout
	queue_free()
