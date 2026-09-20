class_name LootTableEntry
extends Resource
## One weighted slot in a LootTable — item id, amount range rolled per
## hit, and relative drop weight (see LootTable.roll/_pick).

@export var item_id: String = ""
@export var min_amount: int = 1
@export var max_amount: int = 1
@export var weight: float = 1.0
