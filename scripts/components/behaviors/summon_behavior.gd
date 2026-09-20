class_name SummonBehavior
extends EnemyBehavior
## Boss add-spawner: while the player is aggro'd, periodically scatters
## minion_scene instances around the boss, capped at max_minions concurrent.
## Tracked minions are freed when the boss itself dies, so a kill doesn't
## leave orphan spam behind after "Altar cleared".

@export var minion_scene: PackedScene
@export var summon_cooldown: float = 4.0
@export var summon_count: int = 2
@export var max_minions: int = 4
@export var spawn_radius: float = 60.0

var _cooldown_timer: float = 0.0
var _minions: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_rng.randomize()
	enemy.tree_exiting.connect(_despawn_minions)


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick" or minion_scene == null:
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer -= payload.get("delta", 0.0)
		return
	if not _is_player_aggro():
		return
	_minions = _minions.filter(func(m: Node) -> bool: return is_instance_valid(m))
	if _minions.size() >= max_minions:
		return
	_summon()


func _summon() -> void:
	_cooldown_timer = summon_cooldown
	var parent := enemy.get_parent()
	for i in summon_count:
		if _minions.size() >= max_minions:
			break
		var minion: Enemy = minion_scene.instantiate()
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(spawn_radius * 0.5, spawn_radius)
		minion.position = enemy.position + Vector2.RIGHT.rotated(angle) * distance
		parent.add_child(minion)
		_minions.append(minion)


func _despawn_minions() -> void:
	for minion in _minions:
		if is_instance_valid(minion):
			minion.queue_free()
	_minions.clear()
