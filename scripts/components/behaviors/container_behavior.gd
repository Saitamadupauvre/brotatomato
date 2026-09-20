class_name ContainerBehavior
extends Behavior
## Rolls a weighted LootTable on "interacted" and throws the results out
## as scattered world pickups, then empties itself (container stays,
## reusable visually, just has nothing left to give).

@export var loot_table: LootTable
@export var scatter_min_distance: float = 24.0
@export var scatter_max_distance: float = 64.0
@export var scatter_attempts: int = 8

## Set by whoever spawns this container (DungeonPopulator via dungeon.gd)
## so the roll is deterministic per dungeon run instead of drawing from
## global RNG. Left at 0 for containers placed directly in a scene.
var loot_seed: int = 0

var _rolled: bool = false


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name != "interacted" or _rolled:
		return
	_rolled = true
	var contents: Array[LootEntry] = []
	if loot_table != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = loot_seed
		contents = loot_table.roll(rng)
	LootSpawner.spawn(contents, owner_entity, scatter_min_distance, scatter_max_distance, scatter_attempts)
	host.broadcast("contents_emptied")
