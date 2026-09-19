class_name ChaseMovementBehavior
extends EnemyBehavior
## Moves straight at the player at data.move_speed. Today's slime/imp feel.

func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick" or enemy.movement_locked:
		return
	if enemy.player:
		enemy.velocity = enemy.global_position.direction_to(enemy.player.global_position) * enemy.data.move_speed
