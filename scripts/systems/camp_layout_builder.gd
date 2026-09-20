class_name CampLayoutBuilder
extends RefCounted
## Builds a trivial one-room DungeonLayout for the camp: a rectangular
## floor surrounded by a ring of "wall" cells. Not procedurally
## generated, but shaped exactly like DungeonLayout's output so the camp
## can run through ForestSceneKit and get the same ground/shade/tree/
## grass pipeline as the real dungeon, instead of a separate one.


## `gap_width` carves a FLOOR-marked strip through the north forest ring,
## centered on the interior, so ForestDecorator (which only trees WALL
## cells) leaves a treeless hole there instead of a solid canopy — the
## dungeon entrance sits in that hole. 0 = no gap (solid ring all around).
static func build(interior_cols: int, interior_rows: int, forest_depth: int, cell_size: float = 64.0, gap_width: int = 0) -> DungeonLayout:
	var layout := DungeonLayout.new()
	layout.seed = randi()
	layout.cell_size = cell_size
	layout.width = interior_cols + forest_depth * 2
	layout.height = interior_rows + forest_depth * 2
	layout.cells = PackedByteArray()
	layout.cells.resize(layout.width * layout.height)
	var gap_start := forest_depth + (interior_cols - gap_width) / 2
	var gap_end := gap_start + gap_width
	for y in layout.height:
		for x in layout.width:
			var is_interior := x >= forest_depth and x < forest_depth + interior_cols \
				and y >= forest_depth and y < forest_depth + interior_rows
			var is_north_gap := gap_width > 0 and y < forest_depth and x >= gap_start and x < gap_end
			layout.set_cell(x, y, DungeonLayout.Cell.FLOOR if (is_interior or is_north_gap) else DungeonLayout.Cell.WALL)
	return layout


## World-space top-left of the interior floor rect (where camp walls
## and entities should be anchored).
static func interior_origin(layout: DungeonLayout, forest_depth: int) -> Vector2:
	return Vector2(forest_depth, forest_depth) * layout.cell_size
