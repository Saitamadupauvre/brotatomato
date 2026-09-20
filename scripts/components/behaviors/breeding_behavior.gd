class_name BreedingBehavior
extends Behavior
## Breeding House (#8): on "interacted", walks the 2 closest villagers to
## this house and hides them (spending them as the cost), then starts
## GameState's production timer. Mirrors PlotBehavior's countdown display,
## but the timer itself lives in GameState so it survives a dungeon trip.

@export var time_label_path: NodePath
@export var glow_rect_path: NodePath

var _time_label: Label = null
var _glow_rect: CanvasItem = null
## Ids sent to walk here but not yet arrived — guards against re-trigger.
var _departing_ids: Array[int] = []
var _arrived_ids: Array[int] = []


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_time_label = owner_entity.get_node(time_label_path)
	_glow_rect = owner_entity.get_node(glow_rect_path)
	_update_visuals()


func _process(_delta: float) -> void:
	_update_visuals()


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name != "interacted":
		return
	if not _departing_ids.is_empty() or not GameState.can_start_breeding():
		return
	var candidates: Array = owner_entity.get_tree().get_nodes_in_group("villager")
	candidates.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(owner_entity.global_position) \
			< b.global_position.distance_squared_to(owner_entity.global_position))
	for villager in candidates.slice(0, 2):
		_departing_ids.append(villager.villager_id)
		villager.walk_to_and_hide(owner_entity.global_position, _on_villager_arrived)


func _on_villager_arrived(villager_id: int) -> void:
	_arrived_ids.append(villager_id)
	if _arrived_ids.size() < _departing_ids.size():
		return
	GameState.start_breeding(_departing_ids, owner_entity.global_position)
	_departing_ids.clear()
	_arrived_ids.clear()


## Countdown label + pulsing glow (#8) — both just mirror GameState's
## breeding_active/breeding_timer, no local state of their own.
func _update_visuals() -> void:
	if _time_label != null:
		_time_label.visible = GameState.breeding_active
		if GameState.breeding_active:
			_time_label.text = "%ds" % int(ceil(GameState.breeding_timer))
	if _glow_rect != null:
		_glow_rect.visible = GameState.breeding_active
