extends Node
## État de partie transverse : écran courant, sélection du menu, vague, mode smoke.

signal state_changed(state: String)

## "menu" | "playing" | "shop" | "gameover" | "victory"
var state := "menu"
var shop_return_state := "menu"
var difficulty := "intermediaire"
var element := "sang"
var wave := 1
var run_gold := 0
## Mode Chaos : éléments des boss restant à affronter, mélangés au début de la
## partie. Un boss sort de la file en apparaissant ; comme la vague ne s'achève
## qu'à sa mort, un boss tué ne revient jamais.
var boss_queue: Array[String] = []
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

func diff() -> Dictionary:
	return Data.DIFFICULTIES[difficulty]
