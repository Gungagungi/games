class_name Projectile
extends Node2D
## Brique (Destruction) ou trait d'ombre. Déplacé par `World`.

var velocity := Vector2.ZERO
var dmg := 1.0
var radius := 6.0
var brick := false
var spin := 0.0

var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	var tint := Color(1, 0.3, 0.1, 0.7) if brick else Color(0.7, 0.35, 1, 0.8)
	if brick:
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
	_sprite.rotation = spin if brick else velocity.angle()
