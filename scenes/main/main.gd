extends Node2D
## Scene-specific glue: instantiates a visual Villager whenever GameState
## reports one spawned (from a harvested plot). GameState itself stays
## scene-agnostic — it only tracks data, this scene owns the world node.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/entities/villager.tscn")
const PLOT_SCENE: PackedScene = preload("res://scenes/entities/plot.tscn")

var _villager_nodes: Dictionary = {} # villager_id -> Node2D


func _ready() -> void:
	GameState.villager_spawned.connect(_on_villager_spawned)
	GameState.villager_removed.connect(_on_villager_removed)
	GameState.plot_placed.connect(_on_plot_placed)
	for plot_id in GameState.plots:
		_spawn_plot(plot_id, GameState.plots[plot_id])
	for villager_entry in GameState.villagers:
		_on_villager_spawned(villager_entry["id"], villager_entry["position"])


func _on_villager_spawned(villager_id: int, position: Vector2) -> void:
	var villager: Node2D = VILLAGER_SCENE.instantiate()
	add_child(villager)
	villager.global_position = position
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
	$Plots.add_child(plot)
	plot.global_position = position
