class_name SlamAttackBehavior
extends EnemyBehavior
## Boss melee: telegraphs a red warning circle at the player's current spot,
## holds it for telegraph_duration (boss stands still), then briefly arms an
## AoE hitbox there. The target position is snapshotted at telegraph start,
## not tracked, so a player who moves away in time takes no damage.

@export var trigger_range: float = 220.0
@export var slam_radius: float = 70.0
@export var telegraph_duration: float = 0.8
@export var slam_active_duration: float = 0.15
@export var cooldown: float = 2.5

var _hitbox: HitboxComponent = null
var _warning: Polygon2D = null
var _cooldown_timer: float = 0.0
var _winding_up: bool = false


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_hitbox = HitboxComponent.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 4
	_hitbox.damage = enemy.data.damage
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = slam_radius
	_hitbox.add_child(shape)
	enemy.get_parent().add_child.call_deferred(_hitbox)

	_warning = Polygon2D.new()
	_warning.polygon = _circle_points(slam_radius, 24)
	_warning.color = Color(1.0, 0.15, 0.1, 0.0)
	_warning.visible = false
	enemy.get_parent().add_child.call_deferred(_warning)

	enemy.tree_exiting.connect(_cleanup_visuals)


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick" or _winding_up:
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer -= payload.get("delta", 0.0)
		return
	if enemy.player and enemy.global_position.distance_to(enemy.player.global_position) <= trigger_range:
		_start_telegraph()


func _start_telegraph() -> void:
	_winding_up = true
	enemy.movement_locked = true
	enemy.velocity = Vector2.ZERO
	var target_pos := enemy.player.global_position
	_warning.global_position = target_pos
	_warning.visible = true
	var tween := enemy.get_tree().create_tween()
	tween.tween_property(_warning, "color:a", 0.6, telegraph_duration * 0.5)
	tween.tween_property(_warning, "color:a", 0.9, telegraph_duration * 0.5)
	enemy.get_tree().create_timer(telegraph_duration).timeout.connect(_slam.bind(target_pos))


func _slam(target_pos: Vector2) -> void:
	if not is_instance_valid(_hitbox) or not is_instance_valid(_warning):
		return
	_warning.visible = false
	_hitbox.global_position = target_pos
	_hitbox.monitoring = true
	enemy.get_tree().create_timer(slam_active_duration).timeout.connect(_end_slam)


func _end_slam() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.monitoring = false
	if is_instance_valid(enemy):
		enemy.movement_locked = false
	_winding_up = false
	_cooldown_timer = cooldown


func _cleanup_visuals() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	if is_instance_valid(_warning):
		_warning.queue_free()


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := i * TAU / segments
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
