extends Node2D
## Scene-specific glue: instantiates a visual Villager whenever GameState
## reports one spawned (from a harvested plot). GameState itself stays
## scene-agnostic — it only tracks data, this scene owns the world node.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/entities/villager.tscn")


func _ready() -> void:
	GameState.villager_spawned.connect(_on_villager_spawned)


func _on_villager_spawned(_villager_id: int, position: Vector2) -> void:
	var villager: Node2D = VILLAGER_SCENE.instantiate()
	add_child(villager)
	villager.global_position = position
