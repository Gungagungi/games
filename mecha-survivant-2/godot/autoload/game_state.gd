extends Node
## État de partie transverse : vague courante, tier de difficulté, mode de test.

const FINAL_WAVE: int = 30
const BOSS_EVERY: int = 5

var wave: int = 0
var running: bool = false
var smoke_test: bool = false
## Niveau spécial « Le Destructeur d'univers » : un seul boss, pas de vagues,
## et la partie se gagne en ramassant la gemme dorée qu'il lâche.
var special_level: bool = false
## Combat d'entraînement contre le Cristal, après la gemme dorée : se joue
## dans le niveau spécial (`special_level` reste vrai, aucune vague ne tourne).
var crystal_training: bool = false
## Le Cristal se débloque en ramassant la gemme dorée, une fois pour toutes :
## l'écran-titre propose alors de l'affronter. Seule donnée gardée d'une
## partie à l'autre, dans `PROGRESS_PATH` (IndexedDB sur le web).
var crystal_unlocked: bool = false
const PROGRESS_PATH := "user://progression.cfg"
## Commandes tactiles (`TouchControls`) : allumé au premier toucher, éteint à
## la première touche de clavier. Le tir vient alors de `touch_fire` et vise
## seul, faute de pointeur.
var touch_mode: bool = false
var touch_fire: bool = false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) == OK:
		crystal_unlocked = bool(cfg.get_value("progression", "cristal", false))

## Débloque le Cristal et l'enregistre. Le mode smoke ne touche pas au disque :
## `check.sh` débloquerait sinon le Cristal sur le poste qui le lance.
func unlock_crystal() -> void:
	crystal_unlocked = true
	if smoke_test:
		return
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	cfg.set_value("progression", "cristal", true)
	var err := cfg.save(PROGRESS_PATH)
	if err != OK:
		push_warning("progression non enregistrée (%s)" % error_string(err))

## Difficulté : identique à la v1 (`tier = floor((wave-1)/2)`).
func tier() -> int:
	return maxi(0, (wave - 1) / 2)

func is_boss_wave(n: int) -> bool:
	return n == 1 or n % BOSS_EVERY == 0

func enemy_count(n: int) -> int:
	return 5 + n * 2

## Intervalle de spawn en secondes (v1 : clamp(50 - n*1.5, 14, 50) frames à 60 fps).
func spawn_interval(n: int) -> float:
	return clampf(50.0 - n * 1.5, 14.0, 50.0) / 60.0

func reset(start_wave: int, special: bool = false) -> void:
	wave = start_wave
	special_level = special
	crystal_training = false
	running = true
