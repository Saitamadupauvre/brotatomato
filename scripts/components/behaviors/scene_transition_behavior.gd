class_name SceneTransitionBehavior
extends Behavior
## Drops onto any Interactable to make it a scene-transition point
## (Camp <-> Dungeon). Routes through SceneRouter, never changes the
## scene itself.

enum Destination { CAMP, DUNGEON }

@export var destination: Destination


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name != "interacted":
		return
	AudioManager.play(&"scene_transition")
	match destination:
		Destination.CAMP:
			SceneRouter.go_to_camp()
		Destination.DUNGEON:
			SceneRouter.go_to_dungeon()
