class_name RangedAttackBehavior
extends EnemyBehavior
## "Arrows" — fires a Projectile at the player when in range, on a
## cooldown. Doesn't touch velocity/movement_locked, so it layers cleanly
## on top of a movement behavior like KiteMovementBehavior.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/dungeon/projectile.tscn")

@export var attack_range: float = 300.0
@export var cooldown: float = 1.5

var _cooldown_timer: float = 0.0


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick":
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer -= payload.get("delta", 0.0)
		return
	if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) <= attack_range:
		_fire()


func _fire() -> void:
	_cooldown_timer = cooldown
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.damage = enemy.data.damage
	projectile.position = enemy.position
	projectile.rotation = enemy.global_position.direction_to(enemy.player.global_position).angle()
	enemy.get_parent().add_child.call_deferred(projectile)
