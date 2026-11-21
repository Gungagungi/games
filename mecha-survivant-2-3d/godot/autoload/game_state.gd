extends Node
## État de partie transverse : vague courante, tier de difficulté, mode de
## test. Les formules sont celles de la v2 (`mecha-survivant-2/godot/autoload/
## game_state.gd`), à l'identique.

const FINAL_WAVE: int = 30
const BOSS_EVERY: int = 5


var wave: int = 0
## Faux pendant les menus, l'écran de pouvoirs et la pause : joueur, ennemis,
## projectiles et vagues sont tous gardés par ce drapeau.
var running: bool = false
## Mode smoke (`-- --smoke`) : partie accélérée sans écran, mech immortel.
var smoke_test: bool = false
## Pilote automatique : le smoke, ou `index.html?demo` pour les captures.
var autopilot: bool = false
## Allumé au premier toucher : tir automatique et boutons à l'écran.
var touch_mode: bool = false

## Difficulté : `tier = floor((wave-1)/2)`, comme la v1 et la v2.
func tier() -> int:
	@warning_ignore("integer_division")
	return maxi(0, (wave - 1) / 2)

## Vagues de boss de la v2. Les boss arrivent avec l'étape 2 : en attendant,
## ces vagues se jouent comme les autres (seul le tirage des types en tient
## compte, comme dans la v2 qui en écarte le flameling).
func is_boss_wave(n: int) -> bool:
	return n == 1 or n % BOSS_EVERY == 0

func enemy_count(n: int) -> int:
	return 5 + n * 2

## Intervalle d'apparition en secondes (v1 : clamp(50 - n*1.5, 14, 50) frames).
func spawn_interval(n: int) -> float:
	return clampf(50.0 - n * 1.5, 14.0, 50.0) / 60.0
