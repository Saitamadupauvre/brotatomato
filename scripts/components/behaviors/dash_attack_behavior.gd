class_name DashAttackBehavior
extends EnemyBehavior
## "Dash into you" — bursts toward the player at high speed when in
## trigger range, dealing contact damage during the burst, then cools down.

@export var trigger_range: float = 250.0
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.4
@export var cooldown: float = 2.0

var _hitbox: HitboxComponent = null
var _cooldown_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _dashing: bool = false


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_hitbox = HitboxComponent.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 4
	_hitbox.damage = enemy.data.damage
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 16.0
	_hitbox.add_child(shape)
	enemy.add_child.call_deferred(_hitbox)


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick":
		return
	var delta: float = payload.get("delta", 0.0)

	if _dashing:
		_dash_timer -= delta
		enemy.velocity = _dash_direction * dash_speed
		if _dash_timer <= 0.0:
			_end_dash()
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return

	if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) <= trigger_range:
		_start_dash()


func _start_dash() -> void:
	_dashing = true
	enemy.movement_locked = true
	_dash_direction = enemy.global_position.direction_to(enemy.player.global_position)
	_dash_timer = dash_duration
	_hitbox.monitoring = true


func _end_dash() -> void:
	_dashing = false
	_hitbox.monitoring = false
	_cooldown_timer = cooldown
	enemy.movement_locked = false
