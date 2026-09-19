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
@export var container_scene: PackedScene
