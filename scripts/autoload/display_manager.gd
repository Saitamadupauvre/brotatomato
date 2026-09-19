extends Node
## Fullscreen toggle, works regardless of active scene. No other display
## responsibility — window sizing/stretch itself is project.godot config.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var window := get_window()
		if window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
		else:
			window.mode = Window.MODE_FULLSCREEN
