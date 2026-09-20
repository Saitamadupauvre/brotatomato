extends Node2D
## Dungeon scene root: generates the layout, then builds the world from
## it (collision, visuals, spawn/exit). Generation is data-only
## (DungeonGenerator); this script is the only place nodes get created
## from that data. Transitions still go through SceneRouter.

const TREE_SCENE: PackedScene = preload("res://scenes/dungeon/tree.tscn")

@export var config: DungeonConfig
## 0 = random seed each run. Set non-zero to reproduce a layout.
@export var seed_override: int = 0
## How many cells deep into the forest trees are drawn. Deeper is never
## visible from the floor, so it is skipped to keep node count down.
@export var tree_depth: int = 4
@export var trees_per_cell: float = 1.0
## Chance per floor cell (inside grass patches) to get a tuft.
@export_range(0.0, 1.0) var grass_density: float = 0.6
## Show the contour/fill placeholder under the trees.
@export var debug_contours: bool = false

var layout: DungeonLayout

@onready var _player: CharacterBody2D = $World/Player
@onready var _hud: HUD = $UI/HUD
@onready var _camp_exit: Node2D = $World/CampExit
@onready var _trees: Node2D = $World/Trees
@onready var _enemies: Node2D = $World/Enemies
@onready var _props: Node2D = $World/Props
@onready var _forest_body: StaticBody2D = $Forest/Body
@onready var _forest_debug: Node2D = $Forest/Debug
@onready var _ground: ColorRect = $Ground
@onready var _grass: GrassField = $Grass
@onready var _shade: ColorRect = $Shade
@onready var _wave_bar: Control = $UI/WaveBar
@onready var _popup: PopupModal = $UI/Popup
## How many floor cells the forest shadow reaches before full brightness.
@export var shade_falloff_cells: int = 8


func _ready() -> void:
	var seed := seed_override if seed_override != 0 else randi()
	layout = DungeonGenerator.generate(config, seed)
	print("Dungeon seed: ", seed, " size ", layout.width, "x", layout.height, " max_distance ", layout.max_distance)

	_build_ground()
	_build_shade()
	_build_forest()
	_build_trees()
	_build_grass()
	_place_player()
	_hud.setup_minimap(layout, _player)
	_place_exit()
	_place_altar()
	_populate()
	GameState.life_lost.connect(_on_life_lost)


## Names the villager just lost (#37) — doesn't gate the 0-tomatoes
## auto-route in SceneRouter, which listens to player_died independently.
func _on_life_lost(_remaining: int, villager_names: Array[String]) -> void:
	if villager_names.is_empty():
		return
	_popup.show_message("%s died" % ", ".join(villager_names))


func _build_ground() -> void:
	_ground.size = layout.world_size()


## One StaticBody2D, one CollisionPolygon2D per contour loop in SEGMENTS
## mode: only the outline collides, so nested loops (clearing inside
## forest inside clearing) need no hole handling. The player is always
## on the floor side, so edge-only collision is enough.
func _build_forest() -> void:
	var loops := ForestContourBuilder.build(layout)
	for pts in loops:
		var shape := CollisionPolygon2D.new()
		shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		shape.polygon = pts
		_forest_body.add_child(shape)
		if debug_contours:
			_add_debug_loop(pts)


## Placeholder until tree sprites land (step 3). Ground is forest-dark;
## the outer loop paints the walkable floor light, islands paint forest
## back on top, and every loop gets its trunk line drawn.
func _add_debug_loop(pts: PackedVector2Array) -> void:
	var fill := Polygon2D.new()
	fill.polygon = pts
	if ForestContourBuilder.is_outer_loop(pts):
		fill.color = Color(0.45, 0.6, 0.3)
		fill.z_index = 0
	else:
		fill.color = Color(0.1, 0.25, 0.1)
		fill.z_index = 1
	_forest_debug.add_child(fill)
	var line := Line2D.new()
	line.points = pts
	line.closed = true
	line.width = 4.0
	line.default_color = Color(0.05, 0.15, 0.05)
	line.z_index = 2
	_forest_debug.add_child(line)


## Trees live in a Y-sorted layer with the player: a trunk lower on
## screen than the player draws over them, so walking up to a treeline
## puts the player under the canopy. One node per tree; only cells
## near the floor get one, so count stays in the low thousands.
func _build_trees() -> void:
	var placements := ForestDecorator.build(layout, tree_depth, trees_per_cell)
	for p in placements:
		var tree: Node2D = TREE_SCENE.instantiate()
		tree.position = p.position
		tree.scale *= p.scale
		if p.flip:
			tree.scale.x = -tree.scale.x
		tree.modulate = Color(p.shade, p.shade, p.shade)
		_trees.add_child(tree)


## Cartoon forest shadow: a one-pixel-per-cell density texture stretched
## over the map, multiplied over ground and grass but under trees and
## actors (z_index between Grass and World). The shader
## quantizes it into hard bands (see forest_shade.gdshader).
func _build_shade() -> void:
	_shade.size = layout.world_size()
	var tex := ImageTexture.create_from_image(ForestDecorator.build_shade_image(layout, shade_falloff_cells))
	(_shade.material as ShaderMaterial).set_shader_parameter("density", tex)


## Grass is flat ground decoration under everything that moves, so it
## needs no Y-sort: GrassField draws every tuft in one call and handles
## sway/push/cut. Player swings cut it.
func _build_grass() -> void:
	_grass.build(ForestDecorator.build_floor_scatter(layout, grass_density, 0x6A55), layout.cell_size)
	_player.melee_swung.connect(_grass.cut_around)


func _place_player() -> void:
	_player.position = layout.cell_to_world(layout.spawn_cell)
	var camera: Camera2D = _player.get_node_or_null("Camera2D")
	if camera:
		var size := layout.world_size()
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(size.x)
		camera.limit_bottom = int(size.y)
		camera.reset_smoothing()


func _place_exit() -> void:
	_camp_exit.position = layout.cell_to_world(layout.exit_cell)


## Fixed, unique placement (unlike zone-driven _populate below) — picks
## one altar variant deterministically from the layout's own seed, wires
## it to the enemy container and wave bar, then paints its clearing so
## the zone reads as a landmark from a distance, not just a small prop.
func _place_altar() -> void:
	if config.altar_scenes.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed ^ 0xA17A2
	var scene: PackedScene = config.altar_scenes[rng.randi_range(0, config.altar_scenes.size() - 1)]
	var altar: Node2D = scene.instantiate()
	altar.position = layout.cell_to_world(layout.altar_cell)
	_props.add_child(altar)

	var altar_behavior: AltarBehavior = altar.get_node("Interactable/Host/AltarBehavior")
	altar_behavior.enemies_container = _enemies
	_wave_bar.bind_altar(altar_behavior)

	_build_altar_zone()


## Distinct stone-colored clearing floor, layered above ground/grass/shade
## (so the forest shadow shader never darkens it) but below trees/actors.
func _build_altar_zone() -> void:
	var patch := Polygon2D.new()
	patch.polygon = _circle_points(config.altar_clear_radius * layout.cell_size * 0.9, 24)
	patch.position = layout.cell_to_world(layout.altar_cell)
	patch.color = Color(0.4, 0.36, 0.32, 1.0)
	patch.z_index = -4
	add_child(patch)


static func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


## Enemies and containers from the zone bands. Runs after the player is
## placed because Enemy looks up the "player" group in _ready.
func _populate() -> void:
	var spawns := DungeonPopulator.build(layout, config)
	var pois: Array[MapPoi] = []
	for spawn in spawns:
		var node: Node2D = spawn.scene.instantiate()
		node.position = spawn.position
		if node is Enemy:
			_enemies.add_child(node)
			pois.append(MapPoi.new(node, MapPoi.Kind.ENEMY))
		else:
			_props.add_child(node)
			pois.append(MapPoi.new(node, MapPoi.Kind.CHEST))
	_hud.set_points_of_interest(pois)
	print("Dungeon spawns: ", spawns.size())
