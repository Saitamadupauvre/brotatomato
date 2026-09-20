class_name GrassField
extends MultiMeshInstance2D
## Every grass tuft in the dungeon, drawn as one MultiMesh. Sway and
## player push run entirely in grass.gdshader; this script feeds it the
## player position and a clock, and owns the only CPU-side state: which
## tufts are cut (per-instance custom data) and a cell->tuft index so
## cut_around() touches ~10 tufts instead of thousands.

signal grass_cut(position: Vector2)

const GRASS_SHADER: Shader = preload("res://assets/shaders/grass.gdshader")

@export var texture_override: Texture2D
## Source-pixels to world scale for one tuft at Placement.scale = 1.
@export var base_scale: float = 0.08
## The tuft's base sits this many source pixels above the image bottom.
@export var base_padding_px: float = 20.0
## Once cut, a tuft cannot be cut again until it has regrown this long
## (matches regrow_delay + regrow_duration in the shader).
@export var regrow_time: float = 30.0

var _clock: float = 0.0
var _cell_size: float = 64.0
var _positions: PackedVector2Array = PackedVector2Array()
var _cut_at: PackedFloat32Array = PackedFloat32Array()
## Vector2i cell -> Array[int] of instance indices in that cell.
var _buckets: Dictionary = {}
var _material: ShaderMaterial


func _ready() -> void:
	add_to_group("grass_field")
	_material = ShaderMaterial.new()
	_material.shader = GRASS_SHADER
	material = _material


func _process(delta: float) -> void:
	_clock += delta
	_material.set_shader_parameter("now", _clock)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_material.set_shader_parameter("player_pos", to_local(player.global_position))


## Builds the MultiMesh from decorator placements. cell_size is only
## used to bucket tufts for cut lookups.
func build(placements: Array[ForestDecorator.Placement], cell_size: float) -> void:
	_cell_size = cell_size
	var tex := texture_override if texture_override else texture
	texture = tex
	var tex_size := tex.get_size()

	_material.set_shader_parameter("half_height", tex_size.y * 0.5)

	var mesh := QuadMesh.new()
	mesh.size = tex_size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = placements.size()

	_positions.resize(placements.size())
	_cut_at.resize(placements.size())
	_cut_at.fill(-INF)
	_buckets.clear()

	# QuadMesh is a y-up 3D mesh: in y-down 2D it renders upside down, so
	# the y scale is negated. Quad is centered; shift it up so the tuft
	# base lands on the placement point.
	var base_offset := Vector2(0.0, -tex_size.y * 0.5 + base_padding_px)
	for i in placements.size():
		var p := placements[i]
		var s := base_scale * p.scale
		var xform := Transform2D(0.0, Vector2(-s if p.flip else s, -s), 0.0, p.position + base_offset * s)
		mm.set_instance_transform_2d(i, xform)
		mm.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
		_positions[i] = p.position
		var cell := Vector2i((p.position / _cell_size).floor())
		if not _buckets.has(cell):
			_buckets[cell] = [] as Array[int]
		_buckets[cell].append(i)
	multimesh = mm


## Read-only check for footstep sound selection: true if any standing
## (uncut, or regrown) tuft is within radius of a world position. Reuses
## cut_around's cell-bucket lookup but never mutates tuft state.
func has_grass_near(world_pos: Vector2, radius: float) -> bool:
	var local_pos := to_local(world_pos)
	var cell := Vector2i((local_pos / _cell_size).floor())
	var reach := int(ceil(radius / _cell_size))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var indices: Array = _buckets.get(cell + Vector2i(dx, dy), [])
			for i in indices:
				if _clock - _cut_at[i] < regrow_time:
					continue
				if _positions[i].distance_squared_to(local_pos) <= radius * radius:
					return true
	return false


## Cuts every standing tuft within radius of a world position. Emits
## grass_cut per tuft so drops/VFX can hook in without touching this.
func cut_around(world_pos: Vector2, radius: float) -> int:
	var local_pos := to_local(world_pos)
	var cell := Vector2i((local_pos / _cell_size).floor())
	var reach := int(ceil(radius / _cell_size))
	var cut := 0
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var indices: Array = _buckets.get(cell + Vector2i(dx, dy), [])
			for i in indices:
				if _clock - _cut_at[i] < regrow_time:
					continue
				if _positions[i].distance_squared_to(local_pos) > radius * radius:
					continue
				_cut_at[i] = _clock
				multimesh.set_instance_custom_data(i, Color(_clock, 1.0, 0.0, 0.0))
				grass_cut.emit(to_global(_positions[i]))
				cut += 1
	return cut
