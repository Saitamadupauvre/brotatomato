extends Node
## Owns every scene transition — nothing else calls
## get_tree().change_scene_to_file(), per ARCHITECTURE.md.

const CAMP_SCENE: String = "res://scenes/main/main.tscn"
const DUNGEON_SCENE: String = "res://scenes/dungeon/dungeon.tscn"


func _ready() -> void:
	GameState.player_died.connect(_on_player_died)


func go_to_camp() -> void:
	## Deferred: go_to_camp can run from _on_player_died, itself reached
	## from a HitboxComponent Area2D signal fired mid physics-step —
	## change_scene_to_file frees the current scene's CollisionObjects
	## immediately, which Godot forbids during a physics callback.
	get_tree().change_scene_to_file.call_deferred(CAMP_SCENE)


func go_to_dungeon() -> void:
	get_tree().change_scene_to_file.call_deferred(DUNGEON_SCENE)


func _on_player_died() -> void:
	GameState.reset_run()
	go_to_camp()
