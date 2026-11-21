class_name FireSkeleton
extends Skeleton
## Squelette archer enflammé (v2 : `fire_skeleton.gd`). Ses flèches et son
## contact embrasent le mech ; le laisser `ENRAGE_DELAY` secondes sans
## riposte lui vaut une boule de feu à la moitié de la vie max du mech.

const FIRE_RANGE := 240.0 * Units.PX
const FIRE_SHOT_INTERVAL := 2.2
const FIRE_ARROW_DAMAGE := 5.0
const IGNITE_DPS := 8.0
const IGNITE_DURATION := 2.5
const ENRAGE_DELAY := 6.0
const FLAME := Color(0.95, 0.45, 0.15)

## Temps écoulé depuis le dernier coup reçu par CE squelette : c'est la
## pression du combat qui déclenche la boule de feu, pas un simple minuteur.
var _pressure_timer := 0.0
var _skull_fire: CPUParticles3D

func _build_body() -> void:
	_build_bones(Color(0.32, 0.24, 0.2), Color(1.0, 0.6, 0.1))
	_shot_cd = 1.2
	if not GameState.smoke_test:
		_skull_fire = Shapes.flames(_body, Vector3(0, 2.1, 0), 0.18, 12, FLAME)
		Shapes.flames(_body, Vector3(0, 1.4, 0), 0.22, 8, FLAME)

func _behaviour(delta: float) -> void:
	var dist := distance_to_mech()
	var sees := sees_mech()
	if dist > FIRE_RANGE or not sees:
		_chase(delta)
	elif dist < FIRE_RANGE * 0.6:
		_chase(delta, -0.6)
	else:
		_hold(delta)
	_shot_cd -= delta
	_draw = maxf(0.0, _draw - delta * 3.0)
	if _shot_cd <= 0.0 and dist <= FIRE_RANGE and sees:
		_shot_cd = FIRE_SHOT_INTERVAL
		_draw = 1.0
		var arrow := shoot(300.0, FIRE_ARROW_DAMAGE, 5.0, FLAME, "fire_arrow")
		arrow.ignite_dps = IGNITE_DPS
		arrow.ignite_duration = IGNITE_DURATION
	_pressure_timer += delta
	if _pressure_timer >= ENRAGE_DELAY:
		_pressure_timer = 0.0
		_enrage_fireball()

func _enrage_fireball() -> void:
	AudioManager.sfx("flameling_cast", -4.0)
	var ball := shoot(260.0, mech.max_hp * 0.5, 12.0, Color(0.98, 0.35, 0.1), "fireball")
	ball.impact_sfx = "fireball_impact"

func take_damage(amount: float, at: Vector3) -> void:
	_pressure_timer = 0.0
	super(amount, at)

func _on_contact() -> void:
	mech.ignite(IGNITE_DPS, IGNITE_DURATION)
