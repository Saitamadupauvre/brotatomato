class_name DialogueBehavior
extends Behavior
## Plays a DialogueData sequence in the shared DialogueBox when the host's
## Interactable reports "interacted". Drop onto any entity's
## Interactable/Host (villager, sign, ...) — no per-source code needed
## beyond assigning the dialogue export.

@export var dialogue: DialogueData


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	match event_name:
		"interacted":
			var box: Node = host.get_tree().get_first_node_in_group("dialogue_ui")
			if box:
				box.play(dialogue)
		"player_out_of_range":
			var box: Node = host.get_tree().get_first_node_in_group("dialogue_ui")
			if box:
				box.close()
