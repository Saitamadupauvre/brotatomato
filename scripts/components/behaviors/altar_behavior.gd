class_name AltarBehavior
extends Behavior
## Turns an Interactable into a wave-combat encounter: idle until
## interacted, spawns a wave of enemies from wave_zone, locks (interact
## is a no-op) until every enemy in the wave is dead, then drops contents
## and shows "Altar cleared". One-shot for the rest of this dungeon visit
## — the dungeon regenerates fresh every time it's entered, so there is
## no separate "reset on reentry" state to manage.

enum AltarState { IDLE, ACTIVE, CLEARED }

## Reused ZoneData: only enemy_scenes/enemy_weights/pick_enemy() matter
## here, density fields are ignored — this isn't zone population, just a
## convenient existing weighted-pick source for wave composition.
@export var wave_zone: ZoneData
@export var wave_size: int = 4
@export var loot_table: LootTable
@export var spawn_radius: float = 96.0
@export var status_label_path: NodePath

signal wave_started(count: int)
signal wave_progress(remaining: int)
signal wave_cleared

## Set externally by dungeon.gd right after instancing the altar — the
## altar has no scene-tree path to World/Enemies of its own.
var enemies_container: Node2D = null

var _state: AltarState = AltarState.IDLE
var _remaining: int = 0
var _status_label: Label = null
var _rng := RandomNumberGenerator.new()


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_status_label = owner_entity.get_node_or_null(status_label_path)
	_rng.randomize()
	_update_visuals()


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name == "interacted" and _state == AltarState.IDLE:
		_start_wave()


func _start_wave() -> void:
	if wave_zone == null or enemies_container == null:
		return
	_state = AltarState.ACTIVE
	_remaining = 0
	_update_visuals()
	for i in wave_size:
		var scene := wave_zone.pick_enemy(_rng)
		if scene == null:
			continue
		var enemy: Enemy = scene.instantiate()
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(spawn_radius * 0.5, spawn_radius)
		enemy.position = owner_entity.position + Vector2.RIGHT.rotated(angle) * distance
		enemies_container.add_child(enemy)
		enemy.health.died.connect(_on_wave_enemy_died)
		_remaining += 1
	wave_started.emit(_remaining)
	if _remaining <= 0:
		_on_wave_cleared()


func _on_wave_enemy_died() -> void:
	_remaining -= 1
	wave_progress.emit(_remaining)
	if _remaining <= 0:
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	_state = AltarState.CLEARED
	var contents: Array[LootEntry] = loot_table.roll(_rng) if loot_table != null else []
	LootSpawner.spawn(contents, owner_entity)
	_update_visuals()
	wave_cleared.emit()
	host.broadcast("contents_emptied")


func _update_visuals() -> void:
	if _status_label == null:
		return
	match _state:
		AltarState.IDLE:
			_status_label.visible = false
		AltarState.ACTIVE:
			_status_label.visible = true
			_status_label.text = "Wave active"
		AltarState.CLEARED:
			_status_label.visible = true
			_status_label.text = "Altar cleared"
