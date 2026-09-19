class_name ContainerBehavior
extends Behavior
## Holds a loot list; on "interacted" throws every entry out as a
## scattered world pickup, then empties itself (container stays, reusable
## visually, just has nothing left to give).

@export var contents: Array[LootEntry] = []
@export var scatter_min_distance: float = 24.0
@export var scatter_max_distance: float = 64.0
@export var scatter_attempts: int = 8


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name == "interacted":
		LootSpawner.spawn(contents, owner_entity, scatter_min_distance, scatter_max_distance, scatter_attempts)
		contents.clear()
		host.broadcast("contents_emptied")
