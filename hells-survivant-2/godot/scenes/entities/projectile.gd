class_name Projectile
extends Node2D
## Brique (Destruction), épée lancée (Soldat blessé) ou trait d'ombre.
## Déplacé par `World`.

var velocity := Vector2.ZERO
var dmg := 1.0
var radius := 6.0
var brick := false
var sword := false
var spin := 0.0

var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	var tint := Color(1, 0.3, 0.1, 0.7) if brick else Color(0.7, 0.35, 1, 0.8)
	if sword:
		tint = Color(0.85, 0.85, 0.95, 0.6)
		_sprite.texture = load("res://assets/sprites/fx/sword.png")
		_sprite.material = Fx.unshaded()
		_sprite.scale = Vector2.ONE * 2.0
	elif brick:
		_sprite.texture = load("res://assets/sprites/fx/brick.png")
		_sprite.scale = Vector2.ONE * (radius / 4.0)
	else:
		_sprite.texture = load("res://assets/sprites/fx/bolt.png")
		_sprite.modulate = Color(0.9, 0.55, 1.0)
		_sprite.material = Fx.unshaded()
		_sprite.scale = Vector2.ONE * (radius / 5.0)
	add_child(Fx.light(Color(tint, 1.0), 0.5 + radius / 12.0, 0.8))
	add_child(Fx.trail(tint))
	add_child(_sprite)

func _process(_delta: float) -> void:
	if sword:
		# La lame du sprite pointe en haut à droite (−45°).
		_sprite.rotation = velocity.angle() + PI / 4.0
	else:
		_sprite.rotation = spin if brick else velocity.angle()
