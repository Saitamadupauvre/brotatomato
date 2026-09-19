class_name LootSpawner
extends RefCounted
## Shared "throw loot out as scattered world pickups" logic, used by any
## Behavior that hands out LootEntry contents (containers, altars).

const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/entities/item_pickup.tscn")


static func spawn(entries: Array[LootEntry], owner_entity: Node2D, scatter_min_distance: float = 24.0, scatter_max_distance: float = 64.0, scatter_attempts: int = 8) -> void:
	for entry in entries:
		_spawn_pickup(entry, owner_entity, scatter_min_distance, scatter_max_distance, scatter_attempts)


static func _spawn_pickup(entry: LootEntry, owner_entity: Node2D, scatter_min_distance: float, scatter_max_distance: float, scatter_attempts: int) -> void:
	var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item_id = entry.item_id
	pickup.amount = entry.amount
	owner_entity.get_parent().add_child(pickup)
	pickup.global_position = owner_entity.global_position
	pickup.toss_to(_pick_scatter_position(owner_entity, scatter_min_distance, scatter_max_distance, scatter_attempts))


static func _pick_scatter_position(owner_entity: Node2D, scatter_min_distance: float, scatter_max_distance: float, scatter_attempts: int) -> Vector2:
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
