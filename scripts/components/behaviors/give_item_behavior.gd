class_name GiveItemBehavior
extends Behavior
## Grants an inventory item when the host's Interactable reports
## "interacted". Drop onto any entity's Interactable/Host (loot pickup,
## water source, ...) — no per-source code needed beyond this export block.

@export var item_id: String = ""
@export var amount: int = 1
@export var consume_on_give: bool = true


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name == "interacted":
		GameState.add_item(item_id, amount)
		if consume_on_give:
			owner_entity.queue_free()
