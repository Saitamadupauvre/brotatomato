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
	preload("res://resources/items/crop.tres"),
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
signal plot_placed(plot_id: int, position: Vector2)
signal item_changed(item_id: String, count: int)
signal crop_stored_changed(count: int)
signal equipment_changed(slot: EquipmentData.EquipSlot, item_id: String)

const STARTING_TOMATOES: int = 3
## TEMP: grants enough materials to test grid placement without looting
## the Container first. Remove/tune before ship.
const STARTING_MATERIALS: int = 30

## Carried tomatoes = lives. Not an inventory item — has its own
## death-trigger semantics, see lose_tomato().
var tomatoes: int = STARTING_TOMATOES

var _inventory: Dictionary = {} # item_id -> count
var _item_defs: Dictionary = {} # item_id -> ItemData
var _equipped: Dictionary = {} # EquipmentData.EquipSlot -> item_id

## Positions of player-placed plots (beyond the 4 built-in ones), keyed by
## a stable id (not by position — floats round-tripped through a Node2D
## transform aren't guaranteed to compare equal), so they can be
## re-instantiated after Main is freed/reloaded by a scene change.
var plots: Dictionary = {} # plot_id -> Vector2

var _next_plot_id: int = 0

## Villager entries spawned from unharvested ripe tomatoes.
## MVP: visual only, no role. { "id": int, "position": Vector2 }
var villagers: Array[Dictionary] = []

var _next_villager_id: int = 0

## Crop chest storage — separate from the carried "crop" inventory count,
## survives scene changes because it lives here rather than on the chest
## node itself (which is freed on scene transition).
var crop_stored: int = 0


func _ready() -> void:
	for item_data in ITEM_DEFS:
		_item_defs[item_data.id] = item_data
	add_item("materials", STARTING_MATERIALS)


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


func add_plot(position: Vector2) -> int:
	var plot_id := _next_plot_id
	_next_plot_id += 1
	plots[plot_id] = position
	plot_placed.emit(plot_id, position)
	return plot_id


## Relocates an already-recorded plot in place — no new id, no refund.
func move_plot(plot_id: int, position: Vector2) -> void:
	plots[plot_id] = position


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


## Moves crop from carried inventory into chest storage.
func deposit_crop(amount: int = 1) -> bool:
	if not remove_item("crop", amount):
		return false
	crop_stored += amount
	crop_stored_changed.emit(crop_stored)
	return true


## Moves crop from chest storage back into carried inventory.
func withdraw_crop(amount: int = 1) -> bool:
	if crop_stored < amount:
		return false
	crop_stored -= amount
	add_item("crop", amount)
	crop_stored_changed.emit(crop_stored)
	return true
