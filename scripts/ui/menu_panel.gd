class_name MenuPanel
extends Control
## Shared open/close for interactable-triggered menus (Shop, Inventory).
## Hidden by default; closes on Escape or E from anywhere.

func _ready() -> void:
	hide()


func _input(event: InputEvent) -> void:
	# _input (not _unhandled_input) so this always wins over a nearby
	# Interactable's own _unhandled_input "interact" check — otherwise
	# closing with E next to the thing you opened could immediately
	# re-trigger it.
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	show()


func close() -> void:
	hide()
