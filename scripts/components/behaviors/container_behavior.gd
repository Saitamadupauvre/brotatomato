class_name ContainerBehavior
extends Behavior
## Holds a loot list; on "interacted" throws every entry out as a
## scattered world pickup, then empties itself (container stays, reusable
## visually, just has nothing left to give).

const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/entities/item_pickup.tscn")

@export var contents: Array[LootEntry] = []
@export var scatter_min_distance: float = 24.0
@export var scatter_max_distance: float = 64.0
@export var scatter_attempts: int = 8


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name == "interacted":
		for entry in contents:
			_spawn_pickup(entry)
		contents.clear()


func _spawn_pickup(entry: LootEntry) -> void:
	var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item_id = entry.item_id
	pickup.amount = entry.amount
	owner_entity.get_parent().add_child(pickup)
	pickup.global_position = owner_entity.global_position
	pickup.toss_to(_pick_scatter_position())


func _pick_scatter_position() -> Vector2:
	var space_state := owner_entity.get_world_2d().direct_space_state
	for i in scatter_attempts:
		var angle := randf() * TAU
		var distance := randf_range(scatter_min_distance, scatter_max_distance)
		var candidate: Vector2 = owner_entity.global_position + Vector2.RIGHT.rotated(angle) * distance
		var query := PhysicsPointQueryParameters2D.new()
		query.position = candidate
		query.collide_with_areas = false
		if space_state.intersect_point(query, 1).is_empty():
			return candidate
	return owner_entity.global_position
