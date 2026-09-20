class_name DungeonConfig
extends Resource
## Tunables for procedural forest generation. Edited in the inspector,
## consumed by DungeonGenerator. Grid = logic cells; visuals scatter on top.

## Logic grid size in cells.
@export var grid_width: int = 120
@export var grid_height: int = 120
## World-space size of one cell in pixels.
@export var cell_size: float = 64.0

@export_group("Cellular automata")
## Initial wall probability before smoothing (0..1).
@export_range(0.0, 1.0) var fill_chance: float = 0.47
## Smoothing passes. More = blobbier, fewer isolated pixels.
@export var smooth_iterations: int = 5
## Low-frequency noise modulates fill_chance so some areas are dense
## forest and some are open meadows instead of uniform static.
@export var noise_frequency: float = 0.03
@export_range(0.0, 0.5) var noise_strength: float = 0.15
## Thickness of the guaranteed forest ring around the map edge.
@export var border_thickness: int = 3
## Cells cleared around the player spawn so it never starts in a wall.
@export var spawn_clear_radius: int = 4

@export_group("Population")
## Enemies are never placed closer than this (in BFS steps) to spawn.
@export var min_enemy_distance: int = 12
## Difficulty bands by distance from spawn. Order does not matter; bands
## may overlap or leave gaps.
@export var zones: Array[ZoneData] = []
## Chest scenes scattered per zone's container_density. Picked randomly
## per spawn, like ZoneData.pick_enemy — see #36 (crop chest added
## alongside the loot chest).
@export var container_scenes: Array[PackedScene] = []
## Parallel to container_scenes. Missing entries count as 1.0.
@export var container_weights: Array[float] = []

@export_group("Altar")
## One fixed-placement altar per dungeon, scene picked at random from this
## pool (each entry its own reward type/loot table) — not zone/density
## driven, since exactly one unique object is placed, not scattered copies.
@export var altar_scenes: Array[PackedScene] = []
## Parallel to altar_scenes. Missing entries count as 1.0 — boss altars are
## given lower weight than regular altars so they roll rarer (see #27).
@export var altar_weights: Array[float] = []
## Floor cells cleared around the altar (bigger than spawn's, so the
## altar clearing reads as a distinct, recognizable zone from a distance).
@export var altar_clear_radius: int = 8
## Band bounds as a fraction of DungeonLayout.max_distance, [min, max].
@export_range(0.0, 1.0) var altar_min_distance_ratio: float = 0.4
@export_range(0.0, 1.0) var altar_max_distance_ratio: float = 0.8


func pick_altar(rng: RandomNumberGenerator) -> PackedScene:
	if altar_scenes.is_empty():
		return null
	var total := 0.0
	for i in altar_scenes.size():
		total += altar_weights[i] if i < altar_weights.size() else 1.0
	var roll := rng.randf() * total
	for i in altar_scenes.size():
		roll -= altar_weights[i] if i < altar_weights.size() else 1.0
		if roll <= 0.0:
			return altar_scenes[i]
	return altar_scenes[-1]


func pick_container(rng: RandomNumberGenerator) -> PackedScene:
	if container_scenes.is_empty():
		return null
	var total := 0.0
	for i in container_scenes.size():
		total += container_weights[i] if i < container_weights.size() else 1.0
	var roll := rng.randf() * total
	for i in container_scenes.size():
		roll -= container_weights[i] if i < container_weights.size() else 1.0
		if roll <= 0.0:
			return container_scenes[i]
	return container_scenes[-1]
