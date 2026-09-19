extends Node2D
## Scene-specific glue: instantiates a visual Villager whenever GameState
## reports one spawned (from a harvested plot). GameState itself stays
## scene-agnostic — it only tracks data, this scene owns the world node.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/entities/villager.tscn")
const PLOT_SCENE: PackedScene = preload("res://scenes/entities/plot.tscn")


func _ready() -> void:
	GameState.villager_spawned.connect(_on_villager_spawned)
	GameState.plot_placed.connect(_on_plot_placed)
	for plot_id in GameState.plots:
		_spawn_plot(plot_id, GameState.plots[plot_id])


func _on_villager_spawned(_villager_id: int, position: Vector2) -> void:
	var villager: Node2D = VILLAGER_SCENE.instantiate()
	add_child(villager)
	villager.global_position = position


func _on_plot_placed(plot_id: int, position: Vector2) -> void:
	_spawn_plot(plot_id, position)


func _spawn_plot(plot_id: int, position: Vector2) -> void:
	var plot: Node2D = PLOT_SCENE.instantiate()
	plot.set_meta("plot_id", plot_id)
	$Plots.add_child(plot)
	plot.global_position = position
