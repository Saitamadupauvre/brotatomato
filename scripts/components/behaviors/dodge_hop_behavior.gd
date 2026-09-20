class_name DodgeHopBehavior
extends EnemyBehavior
## Boss evasion: when the player closes inside trigger_range, bursts
## straight away from them for hop_duration, then cools down. No damage,
## no hitbox — purely a movement burst, same movement_locked coordination
## idiom as DashAttackBehavior. Pairs with KiteMovementBehavior, which
## otherwise owns velocity outside the hop window.

@export var trigger_range: float = 100.0
@export var hop_speed: float = 260.0
@export var hop_duration: float = 0.25
@export var cooldown: float = 3.0

var _cooldown_timer: float = 0.0
var _hop_timer: float = 0.0
var _hopping: bool = false
var _hop_direction: Vector2 = Vector2.ZERO


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick":
		return
	var delta: float = payload.get("delta", 0.0)

	if _hopping:
		_hop_timer -= delta
		enemy.velocity = _hop_direction * hop_speed
		if _hop_timer <= 0.0:
			_hopping = false
			enemy.movement_locked = false
			_cooldown_timer = cooldown
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return

	if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) <= trigger_range:
		_start_hop()


func _start_hop() -> void:
	_hopping = true
	enemy.movement_locked = true
	_hop_direction = enemy.player.global_position.direction_to(enemy.global_position)
	_hop_timer = hop_duration
