class_name Player
extends CharacterBody2D
## Le mech. Stats et timings repris de la v1, convertis de frames en secondes.

const BASE_SPEED := 156.0          # v1 : 2.6 px/frame
const DASH_SPEED := 540.0          # v1 : 9 px/frame
const DASH_DURATION := 8.0 / 60.0
const DASH_COOLDOWN := 45.0 / 60.0
const DASH_INVULN := 10.0 / 60.0
const DASH_COST := 25.0
const STAMINA_REGEN := 18.0
const SHIELD_REGEN := 15.0         # v1 : 0.25/frame
const SHIELD_REGEN_DELAY := 2.0
const AOE_COOLDOWN := 5.0          # v1 : 300 frames
const AOE_RADIUS := 140.0
const AOE_DAMAGE := 60.0
const HIT_INVULN := 0.5

var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var shield_max := 0.0
var shield := 0.0
var speed := BASE_SPEED
var bullet_damage := 12.0
var fire_interval := 24.0 / 60.0
var multi_shot := 1
var aoe_unlocked := false

var invuln := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var aoe_cd := 0.0
var fire_cd := 0.0
var since_damage := 0.0
var alive := true

var _dash_dir := Vector2.ZERO
var _visual: SpriteOrShape

@onready var arena: Node2D = get_parent() as Node2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	_visual = SpriteOrShape.new()
	_visual.texture_name = "player_mech"
	_visual.radius = 18.0
	_visual.shape_color = Color(0.42, 0.78, 0.95)
	add_child(_visual)

func reset_stats() -> void:
	max_hp = 100.0
	hp = max_hp
	max_stamina = 100.0
	stamina = max_stamina
	shield_max = 0.0
	shield = 0.0
	speed = BASE_SPEED
	bullet_damage = 12.0
	fire_interval = 24.0 / 60.0
	multi_shot = 1
	aoe_unlocked = false
	invuln = 0.0
	dash_time = 0.0
	dash_cd = 0.0
	aoe_cd = 0.0
	alive = true
	EventBus.player_stats_changed.emit()

func _physics_process(delta: float) -> void:
	if not alive or not GameState.running:
		return
	_tick_timers(delta)
	_move(delta)
	_handle_shoot(delta)
	_handle_shockwave()

func _tick_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	aoe_cd = maxf(0.0, aoe_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	since_damage += delta
	if dash_time <= 0.0:
		stamina = minf(max_stamina, stamina + STAMINA_REGEN * delta)
	if shield_max > 0.0 and since_damage >= SHIELD_REGEN_DELAY:
		shield = minf(shield_max, shield + SHIELD_REGEN * delta)
	EventBus.player_stats_changed.emit()

func _move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dash_time > 0.0:
		dash_time -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		if Input.is_action_pressed("dash") and dash_cd <= 0.0 \
				and stamina >= DASH_COST and dir != Vector2.ZERO:
			_dash_dir = dir.normalized()
			dash_time = DASH_DURATION
			dash_cd = DASH_COOLDOWN
			invuln = maxf(invuln, DASH_INVULN)
			stamina -= DASH_COST
			AudioManager.sfx("dash")
			velocity = _dash_dir * DASH_SPEED
		else:
			velocity = dir * speed
	move_and_slide()
	_clamp_to_arena()
	if not is_zero_approx(velocity.length()):
		_visual.rotation = velocity.angle() + PI * 0.5

func _clamp_to_arena() -> void:
	var rect := get_viewport_rect()
	position.x = clampf(position.x, 20.0, rect.size.x - 20.0)
	position.y = clampf(position.y, 20.0, rect.size.y - 20.0)

func _handle_shoot(delta: float) -> void:
	if not Input.is_action_pressed("shoot"):
		return
	if fire_cd > 0.0:
		return
	# `fire_interval` est multiplicatif et sans plafond (v1) : sous une frame,
	# on tire plusieurs salves dans la même frame, avec un seul son.
	var salvos := 1
	if fire_interval < delta:
		salvos = mini(20, int(delta / maxf(fire_interval, 0.001)))
	for i in salvos:
		_fire_salvo()
	fire_cd = maxf(fire_interval, 0.0) * salvos
	AudioManager.sfx("shoot")

func _fire_salvo() -> void:
	var aim := (get_global_mouse_position() - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var spread := deg_to_rad(9.0)
	for i in multi_shot:
		var offset := (i - (multi_shot - 1) * 0.5) * spread
		var b := Bullet.new()
		b.setup(global_position, aim.rotated(offset), bullet_damage)
		arena.add_child(b)

func _handle_shockwave() -> void:
	if not aoe_unlocked or aoe_cd > 0.0:
		return
	if not Input.is_action_just_pressed("shockwave"):
		return
	aoe_cd = AOE_COOLDOWN
	AudioManager.sfx("shockwave")
	EventBus.screen_shake_requested.emit(10.0)
	var fx := Shockwave.new()
	fx.position = global_position
	fx.max_radius = AOE_RADIUS
	arena.add_child(fx)
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyBase
		if enemy == null or enemy.is_damage_immune():
			continue
		if enemy.global_position.distance_to(global_position) <= AOE_RADIUS + enemy.radius:
			enemy.take_damage(AOE_DAMAGE)

## Dégâts ordinaires : absorbés par le bouclier, puis les PV. Sans effet
## pendant l'invulnérabilité (dash ou i-frames post-coup).
func take_damage(amount: float) -> void:
	if not alive or invuln > 0.0:
		return
	invuln = HIT_INVULN
	since_damage = 0.0
	var left := amount
	if shield > 0.0:
		var absorbed := minf(shield, left)
		shield -= absorbed
		left -= absorbed
	hp -= left
	AudioManager.sfx("player_hurt")
	EventBus.screen_shake_requested.emit(6.0)
	_visual.flash()
	if hp <= 0.0:
		die()

## Attaque ultime du Titan : tue net, sauf bouclier actif — qui est alors
## entièrement consommé. L'invulnérabilité du dash ne protège pas.
func take_ultimate_damage() -> void:
	if not alive:
		return
	since_damage = 0.0
	if shield > 0.0:
		shield = 0.0
		invuln = HIT_INVULN
		EventBus.screen_shake_requested.emit(24.0)
		EventBus.float_text_requested.emit(global_position, "BOUCLIER DÉTRUIT", Color(0.4, 0.8, 1.0))
		return
	hp = 0.0
	die()

func die() -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	AudioManager.sfx("game_over")
	EventBus.player_died.emit()
