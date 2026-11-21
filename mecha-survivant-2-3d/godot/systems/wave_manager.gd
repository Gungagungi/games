class_name WaveManager
extends Node
## Orchestration des vagues, reprise de la v2 : `5 + n*2` ennemis,
## `tier = floor((n-1)/2)`, trente vagues (`GameState.FINAL_WAVE`) et la 30
## conclut la partie. Les types sont tirés au sort parmi ceux débloqués à
## cette vague (`EnemyStats.available_types`).
##
## Étape 1 du portage : les vagues de boss (1, 5, 10…, 30) se jouent pour
## l'instant comme des vagues ordinaires. Les boss arrivent à l'étape 2.

const SCRIPTS := {
	"zombie": preload("res://actors/enemies/zombie.gd"),
	"skeleton": preload("res://actors/enemies/skeleton.gd"),
	"risen": preload("res://actors/enemies/risen.gd"),
	"shade": preload("res://actors/enemies/shade.gd"),
	"flameling": preload("res://actors/enemies/flameling.gd"),
	"fire_skeleton": preload("res://actors/enemies/fire_skeleton.gd"),
}
## Plafond d'ennemis vivants en même temps : au-delà, l'apparition attend.
## La v2 n'en avait pas, mais la 3D coûte plus cher par ennemi.
const MAX_ALIVE := 70

var world: Node3D
var mech: Mech
var camera: Camera3D
var remaining_to_spawn := 0
var spawn_cd := 0.0
var wave_active := false

func start_wave(n: int) -> void:
	GameState.wave = n
	wave_active = true
	remaining_to_spawn = GameState.enemy_count(n)
	spawn_cd = 0.6
	AudioManager.sfx("wave_start", -4.0)
	AudioManager.play_music("dungeon")
	EventBus.wave_started.emit(n)

func stop() -> void:
	wave_active = false
	remaining_to_spawn = 0

func _process(delta: float) -> void:
	if not wave_active or not GameState.running:
		return
	if remaining_to_spawn > 0:
		spawn_cd -= delta
		if spawn_cd <= 0.0 and living() < MAX_ALIVE:
			spawn_cd = GameState.spawn_interval(GameState.wave)
			_spawn_regular()
			remaining_to_spawn -= 1
	elif living() == 0:
		wave_active = false
		EventBus.wave_cleared.emit(GameState.wave)

func living() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).alive:
			n += 1
	return n

func remaining() -> int:
	return living() + remaining_to_spawn

func _spawn_regular() -> void:
	var types := EnemyStats.available_types(GameState.wave)
	if types.is_empty():
		types = ["zombie"]
	var type: String = types[randi() % types.size()]
	var enemy: Enemy = SCRIPTS[type].new()
	enemy.configure(EnemyStats.scaled(type, GameState.tier()))
	enemy.mech = mech
	var at := Village.current.spawn_point(Vector2(mech.position.x, mech.position.z), camera)
	enemy.position = Vector3(at.x, 0.0, at.y)
	enemy.rotation.y = randf() * TAU
	world.add_child(enemy)
