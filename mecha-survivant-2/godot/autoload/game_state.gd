extends Node
## État de partie transverse : vague courante, tier de difficulté, mode de test.

const FINAL_WAVE: int = 20
const MEGA_BOSS_WAVE: int = 15
const BOSS_EVERY: int = 5

var wave: int = 0
var running: bool = false
var smoke_test: bool = false

## Difficulté : identique à la v1 (`tier = floor((wave-1)/2)`).
func tier() -> int:
	return maxi(0, (wave - 1) / 2)

func is_boss_wave(n: int) -> bool:
	return n % BOSS_EVERY == 0

func enemy_count(n: int) -> int:
	return 5 + n * 2

## Intervalle de spawn en secondes (v1 : clamp(50 - n*1.5, 14, 50) frames à 60 fps).
func spawn_interval(n: int) -> float:
	return clampf(50.0 - n * 1.5, 14.0, 50.0) / 60.0

func reset(start_wave: int) -> void:
	wave = start_wave
	running = true
