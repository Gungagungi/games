class_name FireSkeleton
extends EnemyBase
## Squelette archer enflammé (vagues 1-19, jamais en combat de boss puisque le
## pool ordinaire ne tourne pas pendant ceux-ci). Ses flèches et son contact
## embrasent le joueur ; le laisser trop longtemps sans riposte lui vaut une
## boule de feu qui retire la moitié de sa vie max.

const RANGE := 240.0
const SHOT_INTERVAL := 2.2
const ARROW_DAMAGE := 5.0
const IGNITE_DPS := 8.0
const IGNITE_DURATION := 2.5
const ENRAGE_DELAY := 6.0

var _shot_cd := 1.2
## Temps écoulé depuis le dernier coup reçu par CE squelette : c'est la
## pression du combat qui déclenche la boule de feu, pas un simple minuteur.
var _pressure_timer := 0.0

func _shape_kind() -> String:
	return "square"

func _behaviour(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if dist > RANGE:
		_chase(delta)
	elif dist < RANGE * 0.6:
		_chase(delta, -0.6)
	_shot_cd -= delta
	if _shot_cd <= 0.0 and dist <= RANGE:
		_shot_cd = SHOT_INTERVAL
		_shoot()
	_pressure_timer += delta
	if _pressure_timer >= ENRAGE_DELAY:
		_pressure_timer = 0.0
		_enrage_fireball()

func _shoot() -> void:
	var dir := (player.global_position - global_position).normalized()
	var arrow := EnemyProjectile.new()
	arrow.setup(global_position, dir, 300.0, ARROW_DAMAGE, 5.0,
		Color(0.95, 0.45, 0.15), "proj_fireball")
	arrow.ignite_dps = IGNITE_DPS
	arrow.ignite_duration = IGNITE_DURATION
	get_parent().add_child(arrow)

func _enrage_fireball() -> void:
	AudioManager.sfx("flameling_cast")
	var dir := (player.global_position - global_position).normalized()
	var ball := EnemyProjectile.new()
	ball.setup(global_position, dir, 260.0, player.max_hp * 0.5, 12.0,
		Color(0.98, 0.35, 0.1), "proj_fireball")
	ball.impact_sfx = "fireball_impact"
	get_parent().add_child(ball)

func take_damage(amount: float) -> void:
	_pressure_timer = 0.0
	super(amount)

## `_contact_cd` ne repasse à `CONTACT_INTERVAL` que quand la base vient
## d'infliger des dégâts de contact — c'est ce qui distingue un coup réel
## d'un simple survol pendant l'immunité ou le cooldown.
func _check_contact() -> void:
	super()
	if _contact_cd == CONTACT_INTERVAL:
		player.ignite(IGNITE_DPS, IGNITE_DURATION)
