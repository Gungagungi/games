class_name WaveManager
extends Node
## Orchestration des vagues, à l'identique de la v1 :
## `5 + n*2` ennemis, `tier = floor((n-1)/2)`, boss toutes les 5 vagues, plus
## la vague 1 qui ouvre le jeu sur le Titan de la Mort.
##
## Le Titan de la Mort annoncé depuis la v1 n'a en réalité qu'1 point de vie —
## un leurre qui meurt au premier coup, dès la vague 1. Sa mort ne déclenche
## pas `boss_defeated` (voir `titan_decoy.gd`) mais une réplique pausée ; une
## fois le dialogue refermé, la vague se termine normalement. Le vrai combat
## final, le Boss Galaxie, apparaît directement à la vague 20 — sans leurre.

const BOSS_BY_WAVE := {
	1: "res://scenes/bosses/titan_decoy.gd",
	5: "res://scenes/bosses/giant_knight.gd",
	10: "res://scenes/bosses/sewer_monster.gd",
	15: "res://scenes/bosses/zombie_titan.gd",
	20: "res://scenes/bosses/galaxy_boss.gd",
}
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
	"fire_skeleton": "res://scenes/enemies/fire_skeleton.gd",
}

func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.titan_decoy_defeated.connect(_on_titan_decoy_defeated)

func start_wave(n: int) -> void:
	GameState.wave = n
	wave_active = true
	_boss_alive = false
	AudioManager.sfx("wave_start")
	EventBus.wave_started.emit(n)
	if GameState.is_boss_wave(n):
		remaining_to_spawn = 0
		_spawn_boss(n)
		AudioManager.play_music("titan" if n == 1 else "boss")
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
	_spawn_boss_script(BOSS_BY_WAVE.get(n, "res://scenes/bosses/giant_knight.gd"))

func _spawn_boss_script(path: String) -> void:
	var boss: EnemyBase = load(path).new()
	boss.configure_boss(GameState.tier())
	boss.position = arena.get_viewport_rect().size * Vector2(0.5, 0.25)
	# `call_deferred` : un spawn de boss peut arriver ici en réaction directe à
	# la mort du boss précédent, elle-même remontée depuis la collision d'une
	# balle. Ajouter une Area2D en pleine mise à jour physique fait planter le
	# moteur (« flushing queries ») ; différer l'ajout au prochain tour de
	# boucle l'évite.
	arena.call_deferred("add_child", boss)
	_boss_alive = true
	AudioManager.sfx("boss_spawn")

func _on_boss_defeated() -> void:
	_boss_alive = false
	if wave_active and _living_enemies() <= 1:
		wave_active = false
		EventBus.wave_cleared.emit(GameState.wave)

## Le leurre meurt en un coup sans jamais passer par `boss_defeated` — la
## vague reste active, en pause le temps de la réplique, puis se termine
## normalement une fois le dialogue refermé (via la boucle de `_process`).
func _on_titan_decoy_defeated() -> void:
	_boss_alive = false
	EventBus.dialogue_requested.emit("Titan de la Mort",
		"Ha... tu crois m'avoir vaincu ? Je ne suis même pas le plus puissant d'entre eux.")
