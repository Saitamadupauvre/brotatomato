class_name MeleeAttackBehavior
extends EnemyBehavior
## "Their own sword" — pauses movement and swings a hitbox at the player
## when in range, on a cooldown.

@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.2
@export var swing_duration: float = 0.2

var _hitbox: HitboxComponent = null
var _cooldown_timer: float = 0.0


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_hitbox = HitboxComponent.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 4
	_hitbox.damage = enemy.data.damage
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 20.0
	_hitbox.add_child(shape)
	enemy.add_child.call_deferred(_hitbox)


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick":
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer -= payload.get("delta", 0.0)
		return
	if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) <= attack_range:
		_swing()


func _swing() -> void:
	_cooldown_timer = attack_cooldown
	enemy.movement_locked = true
	enemy.velocity = Vector2.ZERO
	_hitbox.position = enemy.global_position.direction_to(enemy.player.global_position) * 20.0
	_hitbox.monitoring = true
	enemy.get_tree().create_timer(swing_duration).timeout.connect(_end_swing)


func _end_swing() -> void:
	_hitbox.monitoring = false
	enemy.movement_locked = false
