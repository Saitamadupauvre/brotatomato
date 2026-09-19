class_name ForestContourBuilder
extends RefCounted
## Turns the wall/floor grid of a DungeonLayout into closed, smoothed
## outlines of every floor region: the "trunk line" the player collides
## with. Pure geometry, no nodes. Used for collision, debug visuals and
## later the minimap.
##
## Method: every floor cell emits one directed edge per side that touches
## a wall, oriented clockwise around the floor (floor on the right-hand
## side). Edges are chained head-to-tail into closed loops, then each loop
## is rounded with Chaikin corner cutting so staircases become slopes and
## the player slides instead of snagging on 90-degree corners.

## Corner-cutting passes. 1 = 45-degree chamfers, 2 = visibly curved.
const SMOOTH_PASSES: int = 2


## Returns one PackedVector2Array per closed loop, in world space.
## Outer boundaries of floor regions wind clockwise (positive signed area
## in Godot's y-down space); forest islands inside a clearing wind the
## other way. Callers can tell them apart with is_outer_loop().
static func build(layout: DungeonLayout) -> Array[PackedVector2Array]:
	var edges := _collect_edges(layout)
	var loops := _chain_edges(edges)
	var result: Array[PackedVector2Array] = []
	for loop in loops:
		var pts := _to_world(loop, layout.cell_size)
		for i in SMOOTH_PASSES:
			pts = _chaikin(pts)
		result.append(pts)
	return result


static func is_outer_loop(points: PackedVector2Array) -> bool:
	return _signed_area(points) > 0.0


## Edges are keyed by their start corner (Vector2i grid corner coords).
## A corner can have two outgoing edges where two floor cells touch only
## diagonally, so the value is an Array of end corners.
static func _collect_edges(layout: DungeonLayout) -> Dictionary:
	var edges: Dictionary = {} # Vector2i -> Array[Vector2i]
	for y in layout.height:
		for x in layout.width:
			if not layout.is_floor(x, y):
				continue
			var tl := Vector2i(x, y)
			var tr := Vector2i(x + 1, y)
			var br := Vector2i(x + 1, y + 1)
			var bl := Vector2i(x, y + 1)
			# Clockwise: top L->R, right T->B, bottom R->L, left B->T.
			if not layout.is_floor(x, y - 1):
				_add_edge(edges, tl, tr)
			if not layout.is_floor(x + 1, y):
				_add_edge(edges, tr, br)
			if not layout.is_floor(x, y + 1):
				_add_edge(edges, br, bl)
			if not layout.is_floor(x - 1, y):
				_add_edge(edges, bl, tl)
	return edges


static func _add_edge(edges: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if not edges.has(from):
		edges[from] = [] as Array[Vector2i]
	edges[from].append(to)


## Walks edges head-to-tail. At a corner with two candidates (diagonal
## touch), prefers the sharpest right turn so the two loops stay
## separate instead of merging through the pinch point.
static func _chain_edges(edges: Dictionary) -> Array[Array]:
	var loops: Array[Array] = []
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var loop: Array[Vector2i] = [start]
		var current := start
		var incoming := Vector2i.ZERO
		while true:
			var candidates: Array[Vector2i] = edges[current]
			var next := _pick_next(current, incoming, candidates)
			candidates.erase(next)
			if candidates.is_empty():
				edges.erase(current)
			incoming = next - current
			current = next
			if current == start:
				break
			loop.append(current)
		loops.append(loop)
	return loops


static func _pick_next(current: Vector2i, incoming: Vector2i, candidates: Array[Vector2i]) -> Vector2i:
	if candidates.size() == 1 or incoming == Vector2i.ZERO:
		return candidates[0]
	# Right turn in y-down space: cross(incoming, outgoing) > 0.
	var best := candidates[0]
	var best_cross := -2
	for c in candidates:
		var outgoing := c - current
		var cross := incoming.x * outgoing.y - incoming.y * outgoing.x
		if cross > best_cross:
			best_cross = cross
			best = c
	return best


static func _to_world(loop: Array[Vector2i], cell_size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(loop.size())
	for i in loop.size():
		pts[i] = Vector2(loop[i]) * cell_size
	return pts


## Chaikin corner cutting on a closed loop: each edge AB becomes the two
## points at 1/4 and 3/4 along it. Doubles vertex count per pass.
static func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size() * 2)
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		out[i * 2] = a.lerp(b, 0.25)
		out[i * 2 + 1] = a.lerp(b, 0.75)
	return out


static func _signed_area(pts: PackedVector2Array) -> float:
	var area := 0.0
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return area * 0.5
