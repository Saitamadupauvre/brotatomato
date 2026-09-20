class_name LootTable
extends Resource
## Weighted loot pool consumed by ContainerBehavior, mirroring ZoneData's
## weighted-pick pattern (see ZoneData.pick_enemy). Each roll_count draw
## picks one LootTableEntry with replacement and rolls its amount range
## into a LootEntry for LootSpawner — so the same item can drop more than
## once per open, and a near-zero weight entry (e.g. a rare weapon) is
## still possible without being guaranteed.

@export var entries: Array[LootTableEntry] = []
@export var roll_count: int = 1


func roll(rng: RandomNumberGenerator) -> Array[LootEntry]:
	var result: Array[LootEntry] = []
	for i in roll_count:
		var entry := _pick(rng)
		if entry == null:
			continue
		var loot := LootEntry.new()
		loot.item_id = entry.item_id
		loot.amount = rng.randi_range(entry.min_amount, entry.max_amount)
		result.append(loot)
	return result


func _pick(rng: RandomNumberGenerator) -> LootTableEntry:
	if entries.is_empty():
		return null
	var total := 0.0
	for entry in entries:
		total += entry.weight
	var roll := rng.randf() * total
	for entry in entries:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return entries[-1]
