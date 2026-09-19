class_name ZoneData
extends Resource
## One difficulty band of the dungeon, defined by BFS distance from spawn
## as a fraction of the layout's max distance (so it scales with map
## size). DungeonPopulator fills each zone's floor cells from its pools.
## Later boss/altar areas are just more ZoneData entries.

@export var display_name: String = ""
## Band bounds as a fraction of DungeonLayout.max_distance, [min, max).
@export_range(0.0, 1.0) var min_distance_ratio: float = 0.0
@export_range(0.0, 1.0) var max_distance_ratio: float = 1.0

@export_group("Enemies")
@export var enemy_scenes: Array[PackedScene] = []
## Parallel to enemy_scenes. Missing entries count as 1.0.
@export var enemy_weights: Array[float] = []
## Enemies per 100 floor cells in this band.
@export var enemy_density: float = 1.0

@export_group("Containers")
## Containers per 100 floor cells in this band.
@export var container_density: float = 0.2


func pick_enemy(rng: RandomNumberGenerator) -> PackedScene:
	if enemy_scenes.is_empty():
		return null
	var total := 0.0
	for i in enemy_scenes.size():
		total += _weight(i)
	var roll := rng.randf() * total
	for i in enemy_scenes.size():
		roll -= _weight(i)
		if roll <= 0.0:
			return enemy_scenes[i]
	return enemy_scenes[-1]


func _weight(i: int) -> float:
	return enemy_weights[i] if i < enemy_weights.size() else 1.0
