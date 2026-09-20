extends Node
## Owns every scene transition — nothing else calls
## get_tree().change_scene_to_file(), per ARCHITECTURE.md.

const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CAMP_SCENE: String = "res://scenes/main/main.tscn"
const DUNGEON_SCENE: String = "res://scenes/dungeon/dungeon.tscn"
const DEFEAT_SCENE: String = "res://scenes/ui/end_screen_defeat.tscn"
const WIN_SCENE: String = "res://scenes/ui/end_screen_win.tscn"
const LOADING_SCREEN: PackedScene = preload("res://scenes/ui/loading_screen.tscn")

const LOADING_MIN_TIME: float = 0.35
const FADE_DURATION: float = 0.4

var _loading_layer: LoadingScreen = null


func _ready() -> void:
	GameState.player_died.connect(_on_player_died)
	GameState.player_won.connect(_on_player_won)


func go_to_menu() -> void:
	_change_scene(MENU_SCENE)


func go_to_camp() -> void:
	_change_scene(CAMP_SCENE)


func go_to_dungeon() -> void:
	_change_scene(DUNGEON_SCENE)


func go_to_defeat() -> void:
	_change_scene(DEFEAT_SCENE)


func go_to_win() -> void:
	_change_scene(WIN_SCENE)


## Fades to black, swaps the scene, then fades back in. Awaiting (rather
## than call_deferred) already pushes change_scene_to_file past the
## current call stack, which is what makes this safe to call from a
## physics-step signal handler (e.g. player death) in the first place —
## Godot forbids freeing CollisionObjects mid physics-step.
func _change_scene(path: String) -> void:
	_show_loading()
	await _loading_layer.fade_in(FADE_DURATION)
	await get_tree().create_timer(LOADING_MIN_TIME).timeout
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _loading_layer.fade_out(FADE_DURATION)
	_hide_loading()


func _show_loading() -> void:
	if _loading_layer != null:
		return
	_loading_layer = LOADING_SCREEN.instantiate()
	add_child(_loading_layer)


func _hide_loading() -> void:
	if _loading_layer == null:
		return
	_loading_layer.queue_free()
	_loading_layer = null


func _on_player_died() -> void:
	GameState.reset_run()
	go_to_defeat()


func _on_player_won() -> void:
	GameState.reset_run()
	go_to_win()
