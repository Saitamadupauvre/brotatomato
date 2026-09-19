extends Node
## Owns every scene transition — nothing else calls
## get_tree().change_scene_to_file(), per ARCHITECTURE.md.

const CAMP_SCENE: String = "res://scenes/main/main.tscn"
const DUNGEON_SCENE: String = "res://scenes/dungeon/dungeon.tscn"


func _ready() -> void:
	GameState.player_died.connect(_on_player_died)


func go_to_camp() -> void:
	get_tree().change_scene_to_file(CAMP_SCENE)


func go_to_dungeon() -> void:
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _on_player_died() -> void:
	GameState.reset_run()
	go_to_camp()
