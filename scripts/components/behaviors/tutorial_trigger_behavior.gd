class_name TutorialTriggerBehavior
extends Behavior
## Plays a one-shot tutorial dialogue (#91) the first time the player gets
## in range of the host's Interactable. Drop onto any entity's Host
## (plot, shop, container, altar, scene transition point, ...) next to its
## other behaviors — no per-entity tutorial code needed. tutorial_id must
## be unique per trigger; TutorialManager tracks it, not this node, so the
## same dialogue never replays even if the entity is freed and re-created.

@export var tutorial_id: String
@export var dialogue: DialogueData


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name != "player_in_range":
		return
	TutorialManager.trigger(tutorial_id, dialogue)
