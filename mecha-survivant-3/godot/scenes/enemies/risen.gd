class_name Risen
extends EnemyBase
## Revenant : sort de terre. Pendant l'émergence il est immobile et invulnérable,
## comme dans la v1 (20 frames).

const EMERGE_TIME := 20.0 / 60.0

var _emerging := EMERGE_TIME

func _on_spawn() -> void:
	immune = true
	modulate.a = 0.3

func _behaviour(delta: float) -> void:
	if _emerging > 0.0:
		_emerging -= delta
		modulate.a = lerpf(0.3, 1.0, 1.0 - _emerging / EMERGE_TIME)
		if _emerging <= 0.0:
			immune = false
			modulate.a = 1.0
		return
	_chase(delta)

func _deals_no_contact_damage() -> bool:
	return _emerging > 0.0
