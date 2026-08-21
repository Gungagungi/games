class_name BossBase
extends EnemyBase
## Base des boss. Machine à états de phases : quand la barre tombe à zéro et
## qu'il reste une phase, elle est **remise à plein** et les multiplicateurs
## montent (v1 : `megaAdvancePhase` / `titanAdvancePhase`).

var display_name := "Boss"
var phase := 0
var phase_hp: Array[float] = [500.0]
var speed_mul := 1.0
var damage_mul := 1.0

func _shape_kind() -> String:
	return "circle"

func _sprite_name() -> String:
	return "boss_%s" % type_id

func phase_count() -> int:
	return phase_hp.size()

## Stats de boss. Par défaut : celles des trois boss de rotation de la v1.
func configure_boss(tier: int) -> void:
	is_boss = true
	radius = 42.0
	speed = 54.0 + 3.6 * tier          # v1 : 0.9 + 0.06/tier px/frame
	damage = 20.0 + 4.0 * tier
	phase_hp = [500.0 + 350.0 * tier]
	max_hp = phase_hp[0]
	hp = max_hp

func _ready() -> void:
	super()
	EventBus.boss_spawned.emit(self, display_name, max_hp)
	EventBus.boss_phase_changed.emit(phase + 1, phase_count())
	EventBus.boss_hp_changed.emit(1.0)

func _on_hp_depleted() -> void:
	if phase + 1 < phase_count():
		advance_phase()
	else:
		die()

func advance_phase() -> void:
	phase += 1
	max_hp = phase_hp[phase]
	hp = max_hp
	speed_mul += 0.15
	damage_mul += 0.2
	immune = false
	EventBus.boss_phase_changed.emit(phase + 1, phase_count())
	EventBus.boss_hp_changed.emit(1.0)
	EventBus.screen_shake_requested.emit(18.0)
	EventBus.float_text_requested.emit(
		global_position, "PHASE %d" % (phase + 1), Color(1.0, 0.4, 0.35))
	AudioManager.sfx("boss_spawn")
	_on_phase_started(phase)

func _on_phase_started(_new_phase: int) -> void:
	pass

func hit_damage() -> float:
	return damage * damage_mul

## Le boss garde ses distances plutôt que de coller au joueur.
func _keep_range(delta: float, wanted: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if dist > wanted * 1.1:
		_chase(delta, speed_mul)
	elif dist < wanted * 0.7:
		_chase(delta, -speed_mul * 0.8)

func _shoot_at_player(spd: float, dmg: float, r: float, col: Color,
		sprite: String = "", poison: bool = false) -> void:
	var dir := (player.global_position - global_position).normalized()
	_shoot_dir(dir, spd, dmg, r, col, sprite, poison)

func _shoot_dir(dir: Vector2, spd: float, dmg: float, r: float, col: Color,
		sprite: String = "", poison: bool = false) -> void:
	var p := EnemyProjectile.new()
	p.setup(global_position, dir, spd, dmg, r, col, sprite)
	p.poison = poison
	get_parent().add_child(p)

## Zone d'impact annoncée puis appliquée. Le télégraphe vit plus longtemps que
## le boss : sa closure ne capture donc que des valeurs, jamais `self` ni
## `player`, sinon un boss mort en cours d'annonce plante à l'impact.
func _telegraph_strike(at: Vector2, r: float, dmg: float, wait: float,
		col: Color = Color(1.0, 0.4, 0.3), shake: float = 12.0) -> void:
	var tel := Telegraph.new()
	tel.position = at
	tel.radius = r
	tel.delay = wait
	tel.color = col
	var tree := get_tree()
	tel.on_fire = func(origin: Vector2) -> void:
		var p := tree.get_first_node_in_group("player") as Player
		if p != null and p.alive and p.global_position.distance_to(origin) <= r:
			p.take_damage(dmg)
		EventBus.screen_shake_requested.emit(shake)
	get_parent().add_child(tel)

func _summon(script_path: String, type: String, count: int, cap: int = 8) -> void:
	if _count_of_type(type) >= cap:
		return
	for i in count:
		var minion: EnemyBase = load(script_path).new()
		minion.configure(EnemyStats.scaled(type, GameState.tier()))
		var angle := randf() * TAU
		minion.position = global_position + Vector2.RIGHT.rotated(angle) * 90.0
		get_parent().add_child(minion)

func _count_of_type(type: String) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyBase
		if enemy != null and enemy.alive and enemy.type_id == type:
			n += 1
	return n
