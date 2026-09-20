extends Node2D
## Scene-specific glue: instantiates a visual Villager whenever GameState
## reports one spawned (from a harvested plot). GameState itself stays
## scene-agnostic — it only tracks data, this scene owns the world node.
##
## Ground/shade/trees/grass are built through ForestSceneKit on a
## trivial one-room CampLayoutBuilder layout, so the camp gets the exact
## same forest pipeline (and cuttable grass) as the procedural dungeon
## instead of a hand-rolled copy.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/entities/villager.tscn")
const PLOT_SCENE: PackedScene = preload("res://scenes/entities/plot.tscn")
const BREEDING_HOUSE_SCENE: PackedScene = preload("res://scenes/entities/breeding_house.tscn")
## Camp-intro tutorial (#91) is the one dialogue not tied to an
## Interactable's proximity — it's the very first thing a new run sees, so
## Main triggers it directly instead of via TutorialTriggerBehavior.
const CAMP_INTRO_DIALOGUE: DialogueData = preload("res://resources/dialogue/camp_intro.tres")

const INTERIOR_COLS: int = 20
const INTERIOR_ROWS: int = 13
const CELL_SIZE: float = 64.0
## How many cells deep the forest ring is drawn beyond the walls.
const FOREST_DEPTH: int = 4
const TREES_PER_CELL: float = 1.0
const GRASS_DENSITY: float = 0.6
const SHADE_FALLOFF_CELLS: int = 4
## Treeless hole in the north canopy the dungeon entrance sits in.
const ENTRANCE_GAP_CELLS: int = 4

@onready var _ground: ColorRect = $Ground
@onready var _shade: ColorRect = $Shade
@onready var _grass: GrassField = $Grass
@onready var _trees: Node2D = $World/Trees
@onready var _player: CharacterBody2D = $World/Player

var _villager_nodes: Dictionary = {} # villager_id -> Node2D


func _ready() -> void:
	AudioManager.play_music(&"camp")
	var layout := CampLayoutBuilder.build(INTERIOR_COLS, INTERIOR_ROWS, FOREST_DEPTH, CELL_SIZE, ENTRANCE_GAP_CELLS)
	ForestSceneKit.build_ground(_ground, layout)
	ForestSceneKit.build_shade(_shade, layout, SHADE_FALLOFF_CELLS)
	ForestSceneKit.build_trees(_trees, layout, FOREST_DEPTH, TREES_PER_CELL)
	ForestSceneKit.build_grass(_grass, layout, GRASS_DENSITY, 0x6A55, _player)
	var camera: Camera2D = _player.get_node_or_null("Camera2D")
	if camera:
		ForestSceneKit.limit_camera_to_layout(camera, layout)

	GameState.villager_spawned.connect(_on_villager_spawned)
	GameState.villager_removed.connect(_on_villager_removed)
	GameState.plot_placed.connect(_on_plot_placed)
	GameState.breeding_house_created.connect(_spawn_breeding_house)
	for plot_id in GameState.plots:
		_spawn_plot(plot_id, GameState.plots[plot_id])
	if GameState.breeding_house_placed:
		_spawn_breeding_house(GameState.breeding_house_position)
	for villager_entry in GameState.villagers:
		_on_villager_spawned(villager_entry["id"], villager_entry["position"], villager_entry["name"])
	TutorialManager.trigger("camp_intro", CAMP_INTRO_DIALOGUE)


func _on_villager_spawned(villager_id: int, position: Vector2, villager_name: String) -> void:
	var villager: Villager = VILLAGER_SCENE.instantiate()
	$World.add_child(villager)
	villager.global_position = position
	villager.villager_id = villager_id
	villager.set_villager_name(villager_name)
	_villager_nodes[villager_id] = villager


func _on_villager_removed(villager_id: int) -> void:
	var villager: Node2D = _villager_nodes.get(villager_id)
	if villager:
		villager.queue_free()
		_villager_nodes.erase(villager_id)


func _on_plot_placed(plot_id: int, position: Vector2) -> void:
	_spawn_plot(plot_id, position)


func _spawn_plot(plot_id: int, position: Vector2) -> void:
	var plot: Node2D = PLOT_SCENE.instantiate()
	plot.set_meta("plot_id", plot_id)
	$World/Plots.add_child(plot)
	plot.global_position = position


func _spawn_breeding_house(position: Vector2) -> void:
	var breeding_house: Node2D = BREEDING_HOUSE_SCENE.instantiate()
	$World.add_child(breeding_house)
	breeding_house.global_position = position
