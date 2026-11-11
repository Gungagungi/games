extends Node
## État de partie transverse : écran courant, sélection du menu, vague, mode smoke.

signal state_changed(state: String)

## "menu" | "playing" | "shop" | "gameover" | "victory"
var state := "menu"
var shop_return_state := "menu"
var difficulty := "intermediaire"
var element := "sang"
var wave := 1
## Vague de départ choisie au menu (sélecteur de niveau). Non sauvegardée.
var start_wave := 1
var run_gold := 0
## Mode Chaos : éléments des boss restant à affronter, mélangés au début de la
## partie. Un boss sort de la file en apparaissant ; comme la vague ne s'achève
## qu'à sa mort, un boss tué ne revient jamais.
var boss_queue: Array[String] = []
## Niveau spécial « Conclave des boss » (voir `World.start_boss_rush`).
var boss_rush := false
var smoke_test := false

func set_state(s: String) -> void:
	state = s
	state_changed.emit(s)

func open_shop() -> void:
	shop_return_state = state
	set_state("shop")

func close_shop() -> void:
	set_state(shop_return_state)

func is_chaos() -> bool:
	return element == Data.CHAOS

func elem() -> Dictionary:
	return Data.ELEMENTS[element]

## Dernière vague sélectionnable au menu : celle du boss final de l'élément,
## sinon MAX_START_WAVE (les autres éléments n'ont pas de fin).
const MAX_START_WAVE := 50

func max_start_wave() -> int:
	var final := Data.final_boss(element)
	return int(final["wave"]) if not final.is_empty() else MAX_START_WAVE

func set_start_wave(w: int) -> void:
	start_wave = clampi(w, 1, max_start_wave())

func diff() -> Dictionary:
	return Data.DIFFICULTIES[difficulty]
