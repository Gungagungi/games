class_name WaveManager
extends Node
## Orchestration des vagues, à l'identique de la v1 :
## `5 + n*2` ennemis, `tier = floor((n-1)/2)`, boss toutes les 5 vagues,
## méga-boss en 15, Titan en 20.

const BOSS_ROTATION: Array[String] = ["gravedigger", "bone_colossus", "plague"]
const SPAWN_MARGIN := 60.0

var arena: Node2D
var remaining_to_spawn := 0
var spawn_cd := 0.0
var wave_active := false
var _boss_alive := false

const SCRIPTS := {
	"zombie": "res://scenes/enemies/zombie.gd",
	"skeleton": "res://scenes/enemies/skeleton.gd",
	"risen": "res://scenes/enemies/risen.gd",
	"shade": "res://scenes/enemies/shade.gd",
	"flameling": "res://scenes/enemies/flameling.gd",
}

func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)

func start_wave(n: int) -> void:
	GameState.wave = n
	wave_active = true
	_boss_alive = false
	AudioManager.sfx("wave_start")
	EventBus.wave_started.emit(n)
	if GameState.is_boss_wave(n):
		remaining_to_spawn = 0
		_spawn_boss(n)
		AudioManager.play_music("titan" if n == GameState.FINAL_WAVE else "boss")
	else:
		remaining_to_spawn = GameState.enemy_count(n)
		spawn_cd = 0.0
		AudioManager.play_music("dungeon")

func _process(delta: float) -> void:
	if not wave_active or not GameState.running:
		return
	if remaining_to_spawn > 0:
		spawn_cd -= delta
		if spawn_cd <= 0.0:
			spawn_cd = GameState.spawn_interval(GameState.wave)
			_spawn_regular()
			remaining_to_spawn -= 1
	elif not _boss_alive and _living_enemies() == 0:
		wave_active = false
		EventBus.wave_cleared.emit(GameState.wave)

func _living_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as EnemyBase).alive:
			n += 1
	return n

func _spawn_regular() -> void:
	var types := EnemyStats.available_types(GameState.wave)
	if types.is_empty():
		types = ["zombie"]
	var type: String = types[randi() % types.size()]
	var enemy: EnemyBase = load(SCRIPTS[type]).new()
	enemy.configure(EnemyStats.scaled(type, GameState.tier()))
	enemy.position = _edge_position()
	arena.add_child(enemy)

## Apparition sur un bord de l'arène, hors champ.
func _edge_position() -> Vector2:
	var rect := arena.get_viewport_rect().size
	match randi() % 4:
		0: return Vector2(randf() * rect.x, -SPAWN_MARGIN)
		1: return Vector2(randf() * rect.x, rect.y + SPAWN_MARGIN)
		2: return Vector2(-SPAWN_MARGIN, randf() * rect.y)
		_: return Vector2(rect.x + SPAWN_MARGIN, randf() * rect.y)

func _spawn_boss(n: int) -> void:
	var boss: EnemyBase
	if n == GameState.FINAL_WAVE:
		boss = load("res://scenes/bosses/titan.gd").new()
	elif n == GameState.MEGA_BOSS_WAVE:
		boss = load("res://scenes/bosses/mega_boss.gd").new()
	else:
		var key: String = BOSS_ROTATION[(n / GameState.BOSS_EVERY - 1) % BOSS_ROTATION.size()]
		boss = load("res://scenes/bosses/%s.gd" % key).new()
	boss.configure_boss(GameState.tier())
	boss.position = arena.get_viewport_rect().size * Vector2(0.5, 0.25)
	arena.add_child(boss)
	_boss_alive = true
	AudioManager.sfx("boss_spawn")

func _on_boss_defeated() -> void:
	_boss_alive = false
	if wave_active and _living_enemies() <= 1:
		wave_active = false
		EventBus.wave_cleared.emit(GameState.wave)
