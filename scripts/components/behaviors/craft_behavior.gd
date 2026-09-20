class_name CraftBehavior
extends Behavior
## Spends one item to grant another when the host's Interactable reports
## "interacted" — the smallest generic building block for a crafting
## interaction (#68). Output scatters as a world pickup via LootSpawner,
## same as ContainerBehavior, rather than landing straight in the
## inventory — keeps the "walk over to collect" feel consistent across
## every loot source. No-ops (nothing spent, nothing granted) if the
## player doesn't have enough of the cost item.

@export var cost_item_id: String = "materials"
@export var cost_amount: int = 1
@export var output_item_id: String = ""
@export var output_amount: int = 1
@export var scatter_min_distance: float = 24.0
@export var scatter_max_distance: float = 64.0
@export var scatter_attempts: int = 8


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name == "interacted":
		if GameState.remove_item(cost_item_id, cost_amount):
			var output := LootEntry.new()
			output.item_id = output_item_id
			output.amount = output_amount
			var entries: Array[LootEntry] = [output]
			LootSpawner.spawn(entries, owner_entity, scatter_min_distance, scatter_max_distance, scatter_attempts)
