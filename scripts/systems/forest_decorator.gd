class_name ForestDecorator
extends RefCounted
## Decides where tree sprites go from a DungeonLayout. Pure data: returns
## a list of placements, the scene instances them. Deterministic from
## layout.seed so the forest looks the same for the same run.
##
## Trees only exist on wall cells within `max_depth` cells of a floor cell:
## deeper forest is never reachable or visible, so it is skipped. Trunk is
## anchored at the bottom edge of its cell with random jitter, so the
## visible trunk line sits on the collision contour on south-facing
## edges and the canopy overhangs the wall interior.

class Placement:
	var position: Vector2
	var scale: float
	var flip: bool
	## Trees: 1 = touching floor (Y-sorted with player), higher = deeper
	## forest. Floor scatter: always 0.
	var depth: int
	## Per-instance brightness multiplier (1 = untouched, lower = darker)
	## so a wall of identical sprites reads as many individual trees.
	var shade: float = 1.0


static func build(layout: DungeonLayout, max_depth: int, trees_per_cell: float = 1.0) -> Array[Placement]:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed ^ 0x7EE5
	var depth := _wall_depth(layout, max_depth)
	var result: Array[Placement] = []
	var cs := layout.cell_size
	for y in layout.height:
		for x in layout.width:
			var d := depth[y * layout.width + x]
			if d <= 0:
				continue
			var count := int(trees_per_cell) + (1 if rng.randf() < fmod(trees_per_cell, 1.0) else 0)
			for i in count:
				var p := Placement.new()
				p.position = Vector2(
					(x + rng.randf()) * cs,
					(y + 0.75 + rng.randf() * 0.25) * cs,
				)
				p.scale = rng.randf_range(0.9, 1.15)
				p.flip = rng.randf() < 0.5
				p.depth = d
				p.shade = rng.randf_range(0.65, 1.0)
				result.append(p)
	return result


## Decorative scatter on floor cells (grass, later rocks/flowers). A
## low-frequency noise field gates which cells get anything so tufts
## come in patches instead of even static; `density` is the chance per
## gated cell. Positions are jittered inside the cell. No collision.
static func build_floor_scatter(layout: DungeonLayout, density: float, salt: int, clump_frequency: float = 0.08) -> Array[Placement]:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed ^ salt
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = clump_frequency
	var result: Array[Placement] = []
	var cs := layout.cell_size
	for y in layout.height:
		for x in layout.width:
			if not layout.is_floor(x, y):
				continue
			# noise in [-1, 1]; keep cells in the upper part of the field.
			if noise.get_noise_2d(x, y) < 0.1:
				continue
			if rng.randf() > density:
				continue
			var p := Placement.new()
			p.position = Vector2((x + rng.randf()) * cs, (y + rng.randf()) * cs)
			p.scale = rng.randf_range(0.7, 1.2)
			p.flip = rng.randf() < 0.5
			p.depth = 0
			result.append(p)
	return result


## One value per cell in [0, 1] for the cartoon shade overlay. Any cell
## with trees is full shadow; floor fades to fully bright over
## `falloff_cells` cells away from the treeline, so bright areas are the
## open meadows where no tree is in sight. Result is box-blurred once so
## the overlay shader can quantize it into clean bands.
static func build_shade_image(layout: DungeonLayout, falloff_cells: int = 5) -> Image:
	var floor_depth := _floor_depth(layout, falloff_cells)
	var n := layout.width * layout.height
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		var fd := floor_depth[i]
		if fd == 0:
			raw[i] = 1.0 # wall: trees here
		elif fd > 0:
			raw[i] = 1.0 - float(fd) / float(falloff_cells + 1)
		else:
			raw[i] = 0.0 # open floor beyond the falloff

	var img := Image.create(layout.width, layout.height, false, Image.FORMAT_R8)
	for y in layout.height:
		for x in layout.width:
			var sum := 0.0
			var count := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := Vector2i(x + dx, y + dy)
					if layout.is_inside(q.x, q.y):
						sum += raw[q.y * layout.width + q.x]
						count += 1
			img.set_pixel(x, y, Color(sum / count, 0.0, 0.0))
	return img


## Multi-source BFS from every wall cell into the floor. 0 = wall,
## 1 = floor touching a wall, ... capped at max_depth, -1 = open floor.
static func _floor_depth(layout: DungeonLayout, max_depth: int) -> PackedInt32Array:
	var depth := PackedInt32Array()
	depth.resize(layout.width * layout.height)
	depth.fill(-1)
	var queue: Array[Vector2i] = []
	for y in layout.height:
		for x in layout.width:
			if not layout.is_floor(x, y):
				depth[y * layout.width + x] = 0
				queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var d := depth[p.y * layout.width + p.x]
		if d >= max_depth:
			continue
		for n in DungeonGenerator.NEIGHBORS_8:
			var q := p + n
			if not layout.is_inside(q.x, q.y):
				continue
			var idx := q.y * layout.width + q.x
			if depth[idx] != -1:
				continue
			depth[idx] = d + 1
			queue.append(q)
	return depth


## Multi-source BFS from every floor cell into the walls. 0 = floor,
## 1 = wall touching floor, 2 = one cell deeper... capped at max_depth,
## -1 = deeper than cap (never rendered).
static func _wall_depth(layout: DungeonLayout, max_depth: int) -> PackedInt32Array:
	var depth := PackedInt32Array()
	depth.resize(layout.width * layout.height)
	depth.fill(-1)
	var queue: Array[Vector2i] = []
	for y in layout.height:
		for x in layout.width:
			if layout.is_floor(x, y):
				depth[y * layout.width + x] = 0
				queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var d := depth[p.y * layout.width + p.x]
		if d >= max_depth:
			continue
		for n in DungeonGenerator.NEIGHBORS_8:
			var q := p + n
			if not layout.is_inside(q.x, q.y):
				continue
			var idx := q.y * layout.width + q.x
			if depth[idx] != -1:
				continue
			depth[idx] = d + 1
			queue.append(q)
	return depth
