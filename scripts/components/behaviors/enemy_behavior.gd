class_name EnemyBehavior
extends Behavior
## Base for enemy movement/attack behaviors. Unlike OutlineBehavior or
## PromptBehavior, these are deliberately Enemy-specific — they read
## enemy.player/data/velocity/movement_locked directly rather than
## duck-typing through a generic Node2D contract.

var enemy: Enemy = null


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	enemy = p_owner as Enemy
