class_name BurstRangedAttackBehavior
extends EnemyBehavior
## Boss ranged attack: on cooldown, weighted-random choice between a single
## aimed shot and a "wall of ammo" volley (several Projectiles fanned across
## an arc in one burst). Same non-movement-touching contract as
## RangedAttackBehavior, so it layers on KiteMovementBehavior/DodgeHopBehavior.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/dungeon/projectile.tscn")

@export var attack_range: float = 320.0
@export var cooldown: float = 2.0
@export var single_shot_weight: float = 2.0
@export var volley_weight: float = 1.0
@export var volley_count: int = 6
@export var volley_spread_degrees: float = 50.0

var _cooldown_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_rng.randomize()


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick":
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer -= payload.get("delta", 0.0)
		return
	if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) <= attack_range:
		_cooldown_timer = cooldown
		if _rng.randf() * (single_shot_weight + volley_weight) <= single_shot_weight:
			_fire_single()
		else:
			_fire_volley()


func _fire_single() -> void:
	_fire_at_angle(enemy.global_position.direction_to(enemy.player.global_position).angle())


func _fire_volley() -> void:
	var base_angle := enemy.global_position.direction_to(enemy.player.global_position).angle()
	var spread := deg_to_rad(volley_spread_degrees)
	for i in volley_count:
		var t := 0.0 if volley_count == 1 else float(i) / float(volley_count - 1) - 0.5
		_fire_at_angle(base_angle + t * spread)


func _fire_at_angle(angle: float) -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.damage = enemy.data.damage
	projectile.position = enemy.position
	projectile.rotation = angle
	enemy.get_parent().add_child.call_deferred(projectile)
