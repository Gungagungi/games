class_name Juice
extends RefCounted
## Retours d'impact de la v3, regroupés ici pour rester réglables d'un seul
## endroit : hit-stop, gerbe d'éclats à la mort, image rémanente du dash.
##
## Tout est décoratif : aucune de ces fonctions ne touche à l'état du jeu
## (PV, vagues, collisions). Le hit-stop est coupé en mode smoke, qui pilote
## lui-même `Engine.time_scale` pour accélérer les parties de `check.sh`.

const HITSTOP_SCALE := 0.05

static var _hitstop_until := 0

## Fige presque le temps pendant `seconds` de temps réel. Des appels qui se
## chevauchent prolongent le gel au lieu de s'empiler.
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if GameState.smoke_test or tree == null:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _hitstop_until:
		return
	_hitstop_until = until
	Engine.time_scale = HITSTOP_SCALE
	await tree.create_timer(seconds, true, false, true).timeout
	if Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0

## Gerbe d'éclats carrés (pixel art) à la mort d'un ennemi.
static func death_burst(parent: Node, at: Vector2, color: Color, amount: int = 12,
		spd: float = 140.0) -> void:
	if parent == null or GameState.smoke_test:
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.55
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = spd * 0.4
	p.initial_velocity_max = spd
	p.damping_min = spd * 0.8
	p.damping_max = spd * 1.4
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.5))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true

## Copie figée d'un sprite, qui s'efface sur place : la traînée du dash.
static func afterimage(parent: Node, from: Sprite2D, tint: Color) -> void:
	if parent == null or from == null or GameState.smoke_test:
		return
	var ghost := Sprite2D.new()
	ghost.texture = from.texture
	ghost.hframes = from.hframes
	ghost.frame = from.frame
	ghost.flip_h = from.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate = tint
	ghost.z_index = -1
	parent.add_child(ghost)
	ghost.global_transform = from.global_transform
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)
