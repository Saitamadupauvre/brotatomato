class_name PlacePlotBehavior
extends Behavior
## Replaces the owning plot-slot marker with a real, working Plot once the
## player spends enough materials on it.

const PLOT_SCENE: PackedScene = preload("res://scenes/entities/plot.tscn")

@export var materials_cost: int = 10


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name == "interacted" and GameState.remove_item("materials", materials_cost):
		var plot: Node2D = PLOT_SCENE.instantiate()
		owner_entity.get_parent().add_child(plot)
		plot.global_position = owner_entity.global_position
		owner_entity.queue_free()
