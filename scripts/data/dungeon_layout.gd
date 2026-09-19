class_name DungeonLayout
extends RefCounted
## Output of DungeonGenerator. Pure data: cells, distances, spawn/exit.
## Consumers (dungeon scene, minimap) build nodes from this; they never
## regenerate. Same seed -> identical layout.

enum Cell { WALL, FLOOR }

var seed: int = 0
var width: int = 0
var height: int = 0
var cell_size: float = 64.0
## Flat row-major array of Cell, index = y * width + x.
var cells: PackedByteArray = PackedByteArray()
## BFS distance from spawn per cell, -1 for walls/unreachable.
var distances: PackedInt32Array = PackedInt32Array()
var spawn_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var max_distance: int = 0


func is_inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_cell(x: int, y: int) -> Cell:
	if not is_inside(x, y):
		return Cell.WALL
	return cells[y * width + x] as Cell


func set_cell(x: int, y: int, value: Cell) -> void:
	cells[y * width + x] = value


func is_floor(x: int, y: int) -> bool:
	return get_cell(x, y) == Cell.FLOOR


func get_distance(x: int, y: int) -> int:
	if not is_inside(x, y):
		return -1
	return distances[y * width + x]


## Center of a cell in world space.
func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / cell_size).floor())


func world_size() -> Vector2:
	return Vector2(width, height) * cell_size


## Debug: ASCII dump. '#' wall, '.' floor, 'S' spawn, 'E' exit.
func to_ascii() -> String:
	var lines: PackedStringArray = []
	for y in height:
		var line := ""
		for x in width:
			var p := Vector2i(x, y)
			if p == spawn_cell:
				line += "S"
			elif p == exit_cell:
				line += "E"
			else:
				line += "." if is_floor(x, y) else "#"
		lines.append(line)
	return "\n".join(lines)
