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
## Swaps the status label wording so a boss fight reads as higher stakes
## than a regular wave — purely cosmetic, no behavior difference.
@export var is_boss: bool = false
## Boss altars grant one "key" on clear — the currency that unlocks the
## final-boss altar (see required_key_count below).
@export var grants_key: bool = false
## >0 gates this altar: interacting requires GameState to hold at least
## this many "key" items, which are spent (not just checked) before the
## wave starts. Used by the final-boss altar only.
@export var required_key_count: int = 0
## Clearing this altar wins the run (defeat-the-final-boss win condition).
@export var is_final_boss: bool = false

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
	if event_name != "interacted" or _state != AltarState.IDLE:
		return
	if required_key_count > 0 and GameState.get_item_count("key") < required_key_count:
		_show_insufficient_keys()
		return
	if required_key_count > 0:
		GameState.remove_item("key", required_key_count)
	_start_wave()


func _show_insufficient_keys() -> void:
	if _status_label == null:
		return
	_status_label.visible = true
	_status_label.text = "Need %d keys (have %d)" % [required_key_count, GameState.get_item_count("key")]
	owner_entity.get_tree().create_timer(1.5).timeout.connect(_hide_insufficient_keys)


func _hide_insufficient_keys() -> void:
	if _state == AltarState.IDLE:
		_status_label.visible = false


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
	if grants_key:
		GameState.add_item("key", 1)
	_update_visuals()
	wave_cleared.emit()
	host.broadcast("contents_emptied")
	if is_final_boss:
		GameState.win_game()


func _update_visuals() -> void:
	if _status_label == null:
		return
	match _state:
		AltarState.IDLE:
			_status_label.visible = false
		AltarState.ACTIVE:
			_status_label.visible = true
			_status_label.text = "Boss fight!" if is_boss else "Wave active"
		AltarState.CLEARED:
			_status_label.visible = true
			_status_label.text = "Boss defeated" if is_boss else "Altar cleared"
