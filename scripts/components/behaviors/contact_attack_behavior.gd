class_name ContactAttackBehavior
extends EnemyBehavior
## Hitbox always on, no cooldown. Today's slime/imp touch-damage.

var _hitbox: HitboxComponent = null


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_hitbox = HitboxComponent.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 4
	_hitbox.damage = enemy.data.damage
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 14.0
	_hitbox.add_child(shape)
	enemy.add_child.call_deferred(_hitbox)
