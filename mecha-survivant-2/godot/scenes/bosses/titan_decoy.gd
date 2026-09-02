class_name TitanDecoy
extends BossBase
## Le Titan de la Mort annoncé depuis la v1 — sauf qu'il n'a plus qu'1 point de
## vie. La barre affichée à son apparition (`boss_hp_changed` à 1.0) donne
## l'illusion d'un vrai combat ; le premier coup la vide et le tue.
##
## Sa mort ne passe pas par `die()`/`boss_defeated` (qui ferait conclure la
## vague par une victoire) : elle émet `titan_decoy_defeated`, que
## `WaveManager` relaie en réplique pausée avant de faire entrer le vrai boss
## final, le Boss Galaxie.

func configure_boss(tier: int) -> void:
	super(tier)
	type_id = "titan"
	display_name = "Titan de la Mort"
	radius = 68.0
	xp_color = Color(0.72, 0.24, 0.28)
	phase_hp = [1.0]
	max_hp = phase_hp[0]
	hp = max_hp

func _sprite_name() -> String:
	return "titan"

## Il n'a pas le temps d'agir : un coup suffit à le tuer avant sa première
## attaque.
func _behaviour(_delta: float) -> void:
	pass

func _on_hp_depleted() -> void:
	alive = false
	AudioManager.sfx("boss_death")
	EventBus.enemy_died.emit(global_position, true)
	EventBus.titan_decoy_defeated.emit()
	_play_death_then_free()
