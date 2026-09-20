extends Node2D
## Decorative dungeon behind the main menu: generates a real layout via
## DungeonGenerator/DungeonPopulator (same pipeline as the playable
## dungeon, minus player/exit/altars) and idles enemies in it while the
## camera drifts at a constant speed. A repeating timer is the only thing
## that changes course: on each tick it fades to black, jumps the camera
## to a new floor point with a new random direction, then fades back in —
## the camera itself just moves in a straight line at fixed speed between
## ticks, so it's never fast or slow depending on how far the next point is.
## No player node exists here — enemies just sit idle (movement behaviors
## no-op without enemy.player).

const CONFIG: DungeonConfig = preload("res://resources/dungeon/default_config.tres")

@export var tree_depth: int = 4
@export var trees_per_cell: float = 1.0
@export_range(0.0, 1.0) var grass_density: float = 0.6
@export var shade_falloff_cells: int = 8
@export var max_enemies: int = 12
## Constant camera speed in pixels/second, whatever the next leg's distance.
@export var camera_speed: float = 120.0
## Seconds between fade ticks (each tick relocates + re-aims the camera).
@export var fade_interval: float = 4.0
@export var black_hold_time: float = 0.6
@export var fade_duration: float = 1.0

var layout: DungeonLayout
var _floor_cells: Array[Vector2i] = []
var _direction: Vector2 = Vector2.RIGHT

@onready var _trees: Node2D = $World/Trees
@onready var _enemies: Node2D = $World/Enemies
@onready var _ground: ColorRect = $Ground
@onready var _grass: GrassField = $Grass
@onready var _shade: ColorRect = $Shade
@onready var _camera: Camera2D = $World/Camera2D
@onready var _fade: ColorRect = $FadeLayer/Fade


func _ready() -> void:
	var seed := randi()
	layout = DungeonGenerator.generate(CONFIG, seed)
	_collect_floor_cells()

	ForestSceneKit.build_ground(_ground, layout)
	ForestSceneKit.build_shade(_shade, layout, shade_falloff_cells)
	ForestSceneKit.build_trees(_trees, layout, tree_depth, trees_per_cell)
	_grass.build(ForestDecorator.build_floor_scatter(layout, grass_density, 0x6A55), layout.cell_size)
	ForestSceneKit.limit_camera_to_layout(_camera, layout)

	_spawn_enemies()
	_camera.global_position = _random_floor_point()
	_direction = _random_direction()
	_run_fade_loop()


func _process(delta: float) -> void:
	_camera.global_position += _direction * camera_speed * delta


func _collect_floor_cells() -> void:
	for y in layout.height:
		for x in layout.width:
			if layout.is_floor(x, y):
				_floor_cells.append(Vector2i(x, y))


func _random_floor_point() -> Vector2:
	return layout.cell_to_world(_floor_cells[randi() % _floor_cells.size()])


func _random_direction() -> Vector2:
	return Vector2.RIGHT.rotated(randf() * TAU)


func _spawn_enemies() -> void:
	var spawns := DungeonPopulator.build(layout, CONFIG)
	spawns.shuffle()
	for i in mini(max_enemies, spawns.size()):
		var spawn := spawns[i]
		var node: Node2D = spawn.scene.instantiate()
		if node is Enemy:
			node.position = spawn.position
			_enemies.add_child(node)
		else:
			node.queue_free()


## The only thing that ever changes the camera's course: on each tick,
## fade out, jump to a new floor point with a new direction while black,
## then fade back in — so speed stays constant and only heading/position
## change, on a timer.
func _run_fade_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(fade_interval).timeout
		if not is_inside_tree():
			return
		await _fade_to(1.0)
		if not is_inside_tree():
			return
		_camera.global_position = _random_floor_point()
		_direction = _random_direction()
		await get_tree().create_timer(black_hold_time).timeout
		if not is_inside_tree():
			return
		await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, fade_duration)
	await tw.finished
