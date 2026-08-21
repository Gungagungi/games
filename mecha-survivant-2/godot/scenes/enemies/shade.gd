class_name Shade
extends EnemyBase
## Créature de l'ombre : rapide, alterne des phases intangibles où les balles
## la traversent et où elle ne blesse pas.

const SOLID_TIME := 1.6
const PHASED_TIME := 1.1

var _phased := false
var _timer := SOLID_TIME

func _shape_kind() -> String:
	return "diamond"

func _behaviour(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_phased = not _phased
		_timer = PHASED_TIME if _phased else SOLID_TIME
		modulate.a = 0.35 if _phased else 1.0
		AudioManager.sfx("shade_phase")
	_chase(delta)

func is_damage_immune() -> bool:
	return _phased or super()

func _deals_no_contact_damage() -> bool:
	return _phased
