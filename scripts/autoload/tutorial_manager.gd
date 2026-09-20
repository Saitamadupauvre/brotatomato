extends Node
## Tracks which one-shot tutorial dialogues (#91) have already played this
## session and plays them through the shared DialogueBox. Session-scoped
## only — no save/load exists yet (out of MVP scope per CLAUDE.md), so
## every dialogue replays once per launch, not once ever.

## Key (#91) is item-based rather than location-based — nowhere in the
## dungeon is "the" place a key is guaranteed to first appear, so it's
## triggered off inventory count instead of an Interactable's proximity,
## unlike every other tutorial here.
const KEY_DIALOGUE: DialogueData = preload("res://resources/dialogue/key_intro.tres")
## Teleport-channel (#91, the T-hotkey in player.gd, not the walk-up
## CampExit point) is triggered by the player's first actual life loss,
## not proximity — that's the moment fleeing back to camp matters.
const TELEPORT_CHANNEL_DIALOGUE: DialogueData = preload("res://resources/dialogue/teleport_channel.tres")

var _seen: Dictionary = {} # tutorial_id -> true


func _ready() -> void:
	GameState.item_changed.connect(_on_item_changed)
	GameState.life_lost.connect(_on_life_lost)


func _on_item_changed(item_id: String, count: int) -> void:
	if item_id == "key" and count > 0:
		trigger("key_intro", KEY_DIALOGUE)


func _on_life_lost(_remaining: int, _villager_names: Array[String]) -> void:
	trigger("teleport_channel", TELEPORT_CHANNEL_DIALOGUE)


func has_seen(tutorial_id: String) -> bool:
	return _seen.get(tutorial_id, false)


## Marks tutorial_id seen and plays dialogue in the scene's DialogueBox, if
## one exists. No-op (but still marks seen) if no DialogueBox is in the
## tree, so a caller never needs to null-check before calling.
func trigger(tutorial_id: String, dialogue: DialogueData) -> void:
	if has_seen(tutorial_id) or dialogue == null:
		return
	_seen[tutorial_id] = true
	var box: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if box:
		box.play(dialogue)
