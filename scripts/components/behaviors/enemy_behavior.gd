class_name EnemyBehavior
extends Behavior
## Base for enemy movement/attack behaviors. Unlike OutlineBehavior or
## PromptBehavior, these are deliberately Enemy-specific — they read
## enemy.player/data/velocity/movement_locked directly rather than
## duck-typing through a generic Node2D contract.

## Aggro/leash hysteresis: movement behaviors call _is_player_aggro() before
## acting on enemy.player. leash_range > aggro_range so the enemy doesn't
## flip-flop right at the boundary once it has engaged.
@export var aggro_range: float = 300.0
@export var leash_range: float = 450.0

var enemy: Enemy = null
var _is_aggro: bool = false


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	enemy = p_owner as Enemy


func _is_player_aggro() -> bool:
	if not enemy.player:
		return false
	var distance := enemy.global_position.distance_to(enemy.player.global_position)
	if _is_aggro:
		_is_aggro = distance <= leash_range
	else:
		_is_aggro = distance <= aggro_range
	return _is_aggro
