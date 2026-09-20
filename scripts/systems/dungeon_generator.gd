class_name DungeonGenerator
extends RefCounted
## Builds a DungeonLayout from a DungeonConfig and a seed.
## Pipeline: noise-modulated random fill -> cellular automata smoothing
## -> forced border -> keep largest connected region -> BFS from spawn
## -> exit at the farthest reachable cell.
## All randomness goes through one RandomNumberGenerator seeded once,
## so the same (config, seed) always yields the same layout.

const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const NEIGHBORS_4: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func generate(config: DungeonConfig, seed: int) -> DungeonLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var layout := DungeonLayout.new()
	layout.seed = seed
	layout.width = config.grid_width
	layout.height = config.grid_height
	layout.cell_size = config.cell_size
	layout.cells.resize(layout.width * layout.height)

	_random_fill(layout, config, rng)
	for i in config.smooth_iterations:
		_smooth(layout)
	_force_border(layout, config.border_thickness)
	_keep_largest_region(layout)
	_pick_spawn(layout, config, rng)
	_compute_distances(layout)
	_pick_exit(layout)
	_pick_altars(layout, config, rng)
	return layout


## Initial noise. A low-frequency Perlin field shifts the wall chance
## per cell so the map has dense and open areas rather than uniform static.
static func _random_fill(layout: DungeonLayout, config: DungeonConfig, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = config.noise_frequency
	for y in layout.height:
		for x in layout.width:
			var bias := noise.get_noise_2d(x, y) * config.noise_strength
			var wall := rng.randf() < config.fill_chance + bias
			layout.set_cell(x, y, DungeonLayout.Cell.WALL if wall else DungeonLayout.Cell.FLOOR)


## One cellular-automata pass: a cell becomes wall if 5+ of its 8
## neighbors are wall, floor if 3 or fewer, else unchanged.
## Out-of-bounds counts as wall, which naturally thickens the edges.
static func _smooth(layout: DungeonLayout) -> void:
	var next := layout.cells.duplicate()
	for y in layout.height:
		for x in layout.width:
			var walls := 0
			for n in NEIGHBORS_8:
				if not layout.is_floor(x + n.x, y + n.y):
					walls += 1
			var idx := y * layout.width + x
			if walls >= 5:
				next[idx] = DungeonLayout.Cell.WALL
			elif walls <= 3:
				next[idx] = DungeonLayout.Cell.FLOOR
	layout.cells = next


static func _force_border(layout: DungeonLayout, thickness: int) -> void:
	for y in layout.height:
		for x in layout.width:
			if x < thickness or y < thickness or x >= layout.width - thickness or y >= layout.height - thickness:
				layout.set_cell(x, y, DungeonLayout.Cell.WALL)


## Flood-fill every floor region, keep the biggest, turn the rest into
## wall. Guarantees every remaining floor cell is reachable.
static func _keep_largest_region(layout: DungeonLayout) -> void:
	var region_of := PackedInt32Array()
	region_of.resize(layout.width * layout.height)
	region_of.fill(-1)
	var region_sizes: Array[int] = []

	for y in layout.height:
		for x in layout.width:
			var start := y * layout.width + x
			if not layout.is_floor(x, y) or region_of[start] != -1:
				continue
			var region_id := region_sizes.size()
			var size := _flood_fill(layout, Vector2i(x, y), region_id, region_of)
			region_sizes.append(size)

	if region_sizes.is_empty():
		return
	var largest := 0
	for i in region_sizes.size():
		if region_sizes[i] > region_sizes[largest]:
			largest = i
	for i in region_of.size():
		if region_of[i] != -1 and region_of[i] != largest:
			layout.cells[i] = DungeonLayout.Cell.WALL


static func _flood_fill(layout: DungeonLayout, start: Vector2i, region_id: int, region_of: PackedInt32Array) -> int:
	var stack: Array[Vector2i] = [start]
	region_of[start.y * layout.width + start.x] = region_id
	var count := 0
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		count += 1
		for n in NEIGHBORS_4:
			var q := p + n
			if not layout.is_floor(q.x, q.y):
				continue
			var idx := q.y * layout.width + q.x
			if region_of[idx] != -1:
				continue
			region_of[idx] = region_id
			stack.append(q)
	return count


## Spawn: a random floor cell in the bottom third of the map, then clear a
## disc around it so the player always has room. Bottom bias makes the
## exit (farthest cell) land toward the top: the run reads as "go north".
static func _pick_spawn(layout: DungeonLayout, config: DungeonConfig, rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(layout.height * 2 / 3, layout.height):
		for x in layout.width:
			if layout.is_floor(x, y):
				candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		# Degenerate map (should not happen with sane config): carve center.
		candidates.append(Vector2i(layout.width / 2, layout.height / 2))
	layout.spawn_cell = candidates[rng.randi_range(0, candidates.size() - 1)]

	var r := config.spawn_clear_radius
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var p := layout.spawn_cell + Vector2i(dx, dy)
			if layout.is_inside(p.x, p.y):
				layout.set_cell(p.x, p.y, DungeonLayout.Cell.FLOOR)


## BFS over floor cells from spawn. Distances drive exit placement and
## later difficulty bands (near = weak, far = strong).
static func _compute_distances(layout: DungeonLayout) -> void:
	layout.distances.resize(layout.width * layout.height)
	layout.distances.fill(-1)
	var queue: Array[Vector2i] = [layout.spawn_cell]
	layout.distances[layout.spawn_cell.y * layout.width + layout.spawn_cell.x] = 0
	var head := 0
	layout.max_distance = 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var d := layout.get_distance(p.x, p.y)
		for n in NEIGHBORS_4:
			var q := p + n
			if not layout.is_floor(q.x, q.y) or layout.get_distance(q.x, q.y) != -1:
				continue
			layout.distances[q.y * layout.width + q.x] = d + 1
			layout.max_distance = maxi(layout.max_distance, d + 1)
			queue.append(q)


static func _pick_exit(layout: DungeonLayout) -> void:
	for y in layout.height:
		for x in layout.width:
			if layout.get_distance(x, y) == layout.max_distance:
				layout.exit_cell = Vector2i(x, y)
				return


## Altars: 4 guaranteed fixed floor cells in a mid/far distance band (so
## none sits at the player's feet or overlaps the exit), each with a big
## clear disc around it — same carving technique as _pick_spawn, just
## bigger, so each clearing is a visible landmark. Runs after
## distances/exit are computed; cells newly cleared here keep whatever
## distance value (possibly -1/unreached) they had before clearing, which
## is fine — it only means DungeonPopulator won't drop zone content
## inside the clearing, never that the clearing itself is invalid.
## The 4th (farthest-from-spawn) cell becomes the final boss's, so that
## fight always reads as "the deepest room"; the other 3 (shuffled) are
## the boss altars.
static func _pick_altars(layout: DungeonLayout, config: DungeonConfig, rng: RandomNumberGenerator) -> void:
	var lo := int(config.altar_min_distance_ratio * layout.max_distance)
	var hi := int(config.altar_max_distance_ratio * layout.max_distance)
	var candidates: Array[Vector2i] = []
	for y in layout.height:
		for x in layout.width:
			var d := layout.get_distance(x, y)
			if d < lo or d > hi:
				continue
			if Vector2i(x, y) == layout.exit_cell:
				continue
			candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		var fallback := layout.exit_cell
		layout.boss_altar_cells = [fallback, fallback, fallback]
		layout.final_boss_cell = fallback
		_clear_altar_disc(layout, fallback, config.altar_clear_radius)
		return

	candidates.shuffle()
	var picked: Array[Vector2i] = []
	for c in candidates:
		if picked.size() >= 4:
			break
		var far_enough := true
		for p in picked:
			if Vector2(p).distance_to(Vector2(c)) < config.altar_min_separation:
				far_enough = false
				break
		if far_enough:
			picked.append(c)
	# Small maps may not fit 4 well-separated cells — fill the rest
	# ignoring separation rather than leaving a placement unset.
	var i := 0
	while picked.size() < 4 and i < candidates.size():
		if not picked.has(candidates[i]):
			picked.append(candidates[i])
		i += 1

	var final_index := 0
	var final_distance := -1
	for j in picked.size():
		var d := layout.get_distance(picked[j].x, picked[j].y)
		if d > final_distance:
			final_distance = d
			final_index = j

	layout.final_boss_cell = picked[final_index]
	layout.boss_altar_cells = []
	for j in picked.size():
		if j != final_index:
			layout.boss_altar_cells.append(picked[j])

	for cell in picked:
		_clear_altar_disc(layout, cell, config.altar_clear_radius)


static func _clear_altar_disc(layout: DungeonLayout, center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var p := center + Vector2i(dx, dy)
			if layout.is_inside(p.x, p.y):
				layout.set_cell(p.x, p.y, DungeonLayout.Cell.FLOOR)
