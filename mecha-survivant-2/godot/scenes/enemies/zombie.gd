class_name Zombie
extends EnemyBase
## Le mort-vivant de base : lent, encaisse, fonce droit sur le joueur.

func _on_spawn() -> void:
	if randf() < 0.25:
		AudioManager.sfx("enemy_groan")
