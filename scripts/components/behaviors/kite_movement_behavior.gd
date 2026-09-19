class_name KiteMovementBehavior
extends EnemyBehavior
## Closes distance if too far from the player, backs off if too close,
## holds position in between. Pairs with RangedAttackBehavior.

@export var preferred_range: float = 220.0


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick" or enemy.movement_locked:
		return
	if not _is_player_aggro():
		enemy.velocity = Vector2.ZERO
		return
	var to_player := enemy.player.global_position - enemy.global_position
	var distance := to_player.length()
	if distance > preferred_range:
		enemy.velocity = to_player.normalized() * enemy.data.move_speed
	elif distance < preferred_range * 0.7:
		enemy.velocity = -to_player.normalized() * enemy.data.move_speed
	else:
		enemy.velocity = Vector2.ZERO
