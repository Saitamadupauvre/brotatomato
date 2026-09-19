class_name LootEntry
extends Resource
## One entry in a container's loot list. Per-container contents, embedded
## as sub-resources in that container's .tscn — not a shared item def
## (see ItemData in scripts/data/item_data.gd for that).

@export var item_id: String = ""
@export var amount: int = 1
