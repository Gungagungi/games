class_name Flameling
extends EnemyBase
## Mob de feu : garde ses distances et lance une boule de feu toutes les 3 s,
## incantation comprise. Les dégâts valent 5 % des PV max du joueur, recalculés
## au moment du tir (v1).

const SHOT_INTERVAL := 3.0
const WINDUP := 0.6
const KEEP_DISTANCE := 240.0

var _shot_cd := SHOT_INTERVAL
var _winding := 0.0

func _behaviour(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if _winding > 0.0:
		_winding -= delta
		_visual.scale = Vector2.ONE * (1.0 + 0.3 * (1.0 - _winding / WINDUP))
		if _winding <= 0.0:
			_visual.scale = Vector2.ONE
			_cast()
		return
	if dist > KEEP_DISTANCE * 1.2:
		_chase(delta)
	elif dist < KEEP_DISTANCE * 0.8:
		_chase(delta, -0.8)
	_shot_cd -= delta
	if _shot_cd <= 0.0:
		_shot_cd = SHOT_INTERVAL
		_winding = WINDUP
		AudioManager.sfx("flameling_cast")

func _cast() -> void:
	var dir := (player.global_position - global_position).normalized()
	var fireball := EnemyProjectile.new()
	fireball.setup(global_position, dir, 220.0, player.max_hp * 0.05, 10.0,
		Color(0.98, 0.55, 0.18), "proj_fireball")
	get_parent().add_child(fireball)
