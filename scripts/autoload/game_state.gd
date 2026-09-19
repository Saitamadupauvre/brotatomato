extends Node
## Persistent cross-scene state. Single source of truth for anything that
## must survive a scene change. Only gameplay code (harvest/hit/death
## handlers) should call the mutators below — UI reads via signals.

## Item defs available to the inventory, keyed by ItemData.id once loaded.
## Add a new item: create its .tres in resources/items/, preload it here.
const ITEM_DEFS: Array[ItemData] = [
	preload("res://resources/items/gold.tres"),
	preload("res://resources/items/materials.tres"),
	preload("res://resources/items/water.tres"),
	preload("res://resources/items/dungeon_loot.tres"),
	preload("res://resources/equipment/sword.tres"),
	preload("res://resources/equipment/bow.tres"),
	preload("res://resources/equipment/leather_helmet.tres"),
	preload("res://resources/equipment/leather_chestplate.tres"),
	preload("res://resources/equipment/leather_leggings.tres"),
	preload("res://resources/equipment/leather_boots.tres"),
]

signal tomato_changed(count: int)
signal life_lost(remaining: int)
signal player_died
signal villager_spawned(villager_id: int, position: Vector2)
signal item_changed(item_id: String, count: int)
signal equipment_changed(slot: EquipmentData.EquipSlot, item_id: String)

const STARTING_TOMATOES: int = 3

## Carried tomatoes = lives. Not an inventory item — has its own
## death-trigger semantics, see lose_tomato().
var tomatoes: int = STARTING_TOMATOES

var _inventory: Dictionary = {} # item_id -> count
var _item_defs: Dictionary = {} # item_id -> ItemData
var _equipped: Dictionary = {} # EquipmentData.EquipSlot -> item_id

## Camp plot state, one entry per plot. MVP: 4 plots, index-based.
## Each entry: { "growth_time": float, "ripe": bool }
var plots: Array[Dictionary] = []

## Villager entries spawned from unharvested ripe tomatoes.
## MVP: visual only, no role. { "id": int, "position": Vector2 }
var villagers: Array[Dictionary] = []

var _next_villager_id: int = 0


func _ready() -> void:
	for item_data in ITEM_DEFS:
		_item_defs[item_data.id] = item_data


func get_item_data(item_id: String) -> ItemData:
	return _item_defs.get(item_id)


func get_all_item_ids() -> Array:
	return _item_defs.keys()


func get_item_count(item_id: String) -> int:
	return _inventory.get(item_id, 0)


func add_item(item_id: String, amount: int = 1) -> void:
	_inventory[item_id] = get_item_count(item_id) + amount
	item_changed.emit(item_id, _inventory[item_id])


## Spend semantics: fails (no partial removal) if not enough on hand.
func remove_item(item_id: String, amount: int = 1) -> bool:
	var current: int = get_item_count(item_id)
	if current < amount:
		return false
	_inventory[item_id] = current - amount
	item_changed.emit(item_id, _inventory[item_id])
	return true


## Forced loss (dungeon hit), distinct from a spend — always clamps to 0
## and triggers death at 0 rather than failing silently.
func lose_tomato(amount: int = 1) -> void:
	tomatoes = max(tomatoes - amount, 0)
	tomato_changed.emit(tomatoes)
	life_lost.emit(tomatoes)
	if tomatoes <= 0:
		player_died.emit()


## A villager IS a life, not a separate resource — spawning one always
## grants a tomato. See CLAUDE.md's core mechanic / gardening plan notes.
func spawn_villager(at_position: Vector2) -> void:
	var villager_id := _next_villager_id
	_next_villager_id += 1
	villagers.append({"id": villager_id, "position": at_position})
	villager_spawned.emit(villager_id, at_position)
	tomatoes += 1
	tomato_changed.emit(tomatoes)


## Spends one tomato to plant a seed. Blocks at the last tomato — never
## reaches 0 through planting, deliberately separate from lose_tomato's
## death-trigger path (planting in camp isn't a death condition).
func plant_tomato() -> bool:
	if tomatoes <= 1:
		return false
	tomatoes -= 1
	tomato_changed.emit(tomatoes)
	return true


func reset_run() -> void:
	tomatoes = STARTING_TOMATOES
	tomato_changed.emit(tomatoes)


## Equipping doesn't remove the item from the counted inventory — no
## per-instance item modeling this pass, just a "which owned id is
## equipped" pointer per slot.
func equip_item(item_id: String) -> void:
	var data: ItemData = get_item_data(item_id)
	if data is EquipmentData:
		_equipped[data.slot] = item_id
		equipment_changed.emit(data.slot, item_id)


func get_equipped(slot: EquipmentData.EquipSlot) -> ItemData:
	var id: String = _equipped.get(slot, "")
	return get_item_data(id) if id != "" else null
