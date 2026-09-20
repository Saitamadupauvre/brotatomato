class_name CraftBehavior
extends Behavior
## Spends one item to grant another when the host's Interactable reports
## "interacted" — the smallest generic building block for a crafting
## interaction (#68). No-ops (nothing spent, nothing granted) if the
## player doesn't have enough of the cost item.

@export var cost_item_id: String = "materials"
@export var cost_amount: int = 1
@export var output_item_id: String = ""
@export var output_amount: int = 1


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name == "interacted":
		if GameState.remove_item(cost_item_id, cost_amount):
			GameState.add_item(output_item_id, output_amount)
