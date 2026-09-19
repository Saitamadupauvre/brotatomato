class_name DungeonPopulator
extends RefCounted
## Decides what gets spawned where from a DungeonLayout and the zones in
## a DungeonConfig. Pure data: returns Spawn entries, the scene
## instantiates them. Deterministic from layout.seed.
##
## A cell is a valid spawn if it is floor, all 8 neighbors are floor (so
## nothing spawns under the canopy fringe), it is far enough from the
## player spawn, and it is not the exit cell.

class Spawn:
	var scene: PackedScene
	var position: Vector2
	var zone: ZoneData


static func build(layout: DungeonLayout, config: DungeonConfig) -> Array[Spawn]:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed ^ 0x5CA1E
	var result: Array[Spawn] = []
	for zone in config.zones:
		var cells := _open_cells_in_zone(layout, config, zone)
		_shuffle(cells, rng)
		var enemy_count := int(round(cells.size() * zone.enemy_density / 100.0))
		var container_count := int(round(cells.size() * zone.container_density / 100.0))
		var i := 0
		for n in enemy_count:
			if i >= cells.size():
				break
			var scene := zone.pick_enemy(rng)
			if scene:
				result.append(_spawn(scene, layout, cells[i], zone))
			i += 1
		for n in container_count:
			if i >= cells.size() or config.container_scene == null:
				break
			result.append(_spawn(config.container_scene, layout, cells[i], zone))
			i += 1
	return result


static func _spawn(scene: PackedScene, layout: DungeonLayout, cell: Vector2i, zone: ZoneData) -> Spawn:
	var s := Spawn.new()
	s.scene = scene
	s.position = layout.cell_to_world(cell)
	s.zone = zone
	return s


static func _open_cells_in_zone(layout: DungeonLayout, config: DungeonConfig, zone: ZoneData) -> Array[Vector2i]:
	var lo := int(zone.min_distance_ratio * layout.max_distance)
	var hi := int(zone.max_distance_ratio * layout.max_distance)
	var cells: Array[Vector2i] = []
	for y in layout.height:
		for x in layout.width:
			var d := layout.get_distance(x, y)
			if d < lo or d >= hi or d < config.min_enemy_distance:
				continue
			if Vector2i(x, y) == layout.exit_cell:
				continue
			if not _is_open(layout, x, y):
				continue
			cells.append(Vector2i(x, y))
	return cells


static func _is_open(layout: DungeonLayout, x: int, y: int) -> bool:
	if not layout.is_floor(x, y):
		return false
	for n in DungeonGenerator.NEIGHBORS_8:
		if not layout.is_floor(x + n.x, y + n.y):
			return false
	return true


## Fisher-Yates with our own rng; Array.shuffle() uses the global one
## and would break determinism.
static func _shuffle(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
