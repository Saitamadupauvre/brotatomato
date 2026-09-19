class_name Projectile
extends Node2D
## Travels in a straight line along its own facing (set via rotation at
## spawn), deals damage on contact via its HitboxComponent child, frees
## itself after lifetime.

@export var speed: float = 300.0
@export var lifetime: float = 2.0
@export var target_mask: int = 4 # default: enemy arrows hitting the player's hurtbox layer

var damage: int = 1:
	set(value):
		damage = value
		if _hitbox:
			_hitbox.damage = value

@onready var _hitbox: HitboxComponent = $Hitbox


func _ready() -> void:
	_hitbox.damage = damage
	_hitbox.collision_mask = target_mask
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += transform.x * speed * delta
