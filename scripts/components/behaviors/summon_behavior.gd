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
## Fires an immediate wave as soon as this behavior is set up, instead of
## waiting for the first cooldown tick + aggro (which is instant anyway,
## but this also doesn't require aggro).
@export var summon_on_start: bool = false
## >0: fires one bonus wave the first time HP drops to this fraction of
## max (e.g. 0.5 = half health), on top of the normal periodic summons —
## a "phase 2" beat. <=0 disables.
@export var summon_at_health_fraction: float = 0.0

var _cooldown_timer: float = 0.0
var _minions: Array[Node] = []
var _rng := RandomNumberGenerator.new()
var _health_wave_triggered: bool = false


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_rng.randomize()
	enemy.tree_exiting.connect(_despawn_minions)
	# Host._setup runs before Enemy._ready() assigns its @onready `health`
	# (children ready before parent) — enemy.health is still null here.
	# Defer so this runs after the whole subtree, including Enemy itself,
	# has finished _ready().
	_connect_health.call_deferred()
	if summon_on_start:
		_summon.call_deferred()


func _connect_health() -> void:
	if summon_at_health_fraction > 0.0:
		enemy.health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, max_hp: int) -> void:
	if _health_wave_triggered or max_hp <= 0:
		return
	if float(current) / float(max_hp) <= summon_at_health_fraction:
		_health_wave_triggered = true
		_summon.call_deferred()


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick" or minion_scene == null:
		return
	if _cooldown_timer > 0.0:
		_cooldown_timer -= payload.get("delta", 0.0)
		return
	if not _is_player_aggro():
		return
	_prune_minions()
	if _minions.size() >= max_minions:
		return
	_summon()


## Array.filter() returns an untyped Array, which can't assign back into
## an Array[Node] var — build the pruned list by hand instead.
func _prune_minions() -> void:
	var alive: Array[Node] = []
	for m in _minions:
		if is_instance_valid(m):
			alive.append(m)
	_minions = alive


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
