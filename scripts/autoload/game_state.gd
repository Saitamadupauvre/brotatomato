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
	preload("res://resources/equipment/dash_blade.tres"),
	preload("res://resources/equipment/leather_helmet.tres"),
	preload("res://resources/equipment/leather_chestplate.tres"),
	preload("res://resources/equipment/leather_leggings.tres"),
	preload("res://resources/equipment/leather_boots.tres"),
]

signal tomato_changed(count: int)
signal life_lost(remaining: int, villager_names: Array[String])
signal player_died
signal villager_spawned(villager_id: int, position: Vector2, villager_name: String)
signal villager_removed(villager_id: int)
signal plot_placed(plot_id: int, position: Vector2)
signal item_changed(item_id: String, count: int)
signal crop_stored_changed(count: int)
signal equipment_changed(slot: EquipmentData.EquipSlot, item_id: String)

## TEMP: grants enough materials to test grid placement without looting
## the Container first. Remove/tune before ship.
const STARTING_MATERIALS: int = 30
## TEMP: enough carried crop to seed the starting plots before the first
## harvest comes in. Remove/tune before ship.
const STARTING_CROP: int = 4

## Carried tomatoes = lives = villagers.size(), always — see #36. Never
## set directly; only spawn_villager()/lose_tomato() change it, keeping it
## in lockstep with the villager roster. Not an inventory item.
var tomatoes: int = 0

const STARTING_VILLAGERS: int = 3
## Camp-space spawn points for the starting villager roster, one per
## STARTING_VILLAGERS entry — arbitrary but inside Camp's walls.
const STARTING_VILLAGER_POSITIONS: Array[Vector2] = [
	Vector2(400, 300), Vector2(480, 300), Vector2(560, 300),
]

var crop_stored: int = 0
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
## MVP: visual only, no role. { "id": int, "position": Vector2, "name": String }
var villagers: Array[Dictionary] = []

var _next_villager_id: int = 0

## Name pool for spawned villagers (#36) — flavor/identity only, no
## mechanical effect. Picked at random on spawn, not guaranteed unique.
const VILLAGER_NAMES: Array[String] = [
	"Basil", "Rosemary", "Sage", "Clove", "Pepper", "Saffron", "Ginger",
	"Marjoram", "Thyme", "Chive", "Fennel", "Cumin", "Paprika", "Dill",
	"Mustard", "Nutmeg", "Cinnamon", "Anise", "Coriander", "Tarragon",
]


func _ready() -> void:
	for item_data in ITEM_DEFS:
		_item_defs[item_data.id] = item_data
	add_item("materials", STARTING_MATERIALS)
	add_item("crop", STARTING_CROP)
	_spawn_starting_villagers()
	# TEMP: starting weapon so the held-item sprite (#47) has something to
	# show without going through the shop first. Remove/tune before ship.
	add_item("sword", 1)
	equip_item("sword")


## Villagers ARE the tomato/life count (#36) — spawning the starting
## roster is what gives the player their starting lives, rather than
## setting `tomatoes` directly and risking it drift out of sync with
## villagers.size().
func _spawn_starting_villagers() -> void:
	for i in STARTING_VILLAGERS:
		spawn_villager(STARTING_VILLAGER_POSITIONS[i % STARTING_VILLAGER_POSITIONS.size()])


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
## and triggers death at 0 rather than failing silently. A villager IS a
## life (see spawn_villager), so losing one here pops a villager entry
## too, keeping villagers.size() in sync with tomatoes — see #34.
func lose_tomato(amount: int = 1) -> void:
	tomatoes = max(tomatoes - amount, 0)
	tomato_changed.emit(tomatoes)
	var removed_names: Array[String] = []
	for i in amount:
		if villagers.is_empty():
			break
		var removed: Dictionary = villagers.pop_back()
		removed_names.append(removed["name"])
		villager_removed.emit(removed["id"])
	life_lost.emit(tomatoes, removed_names)
	if tomatoes <= 0:
		player_died.emit()


## A villager IS a life, not a separate resource — spawning one always
## grants a tomato. See CLAUDE.md's core mechanic / gardening plan notes.
func spawn_villager(at_position: Vector2) -> void:
	var villager_id := _next_villager_id
	_next_villager_id += 1
	var villager_name: String = VILLAGER_NAMES[randi() % VILLAGER_NAMES.size()]
	villagers.append({"id": villager_id, "position": at_position, "name": villager_name})
	villager_spawned.emit(villager_id, at_position, villager_name)
	tomatoes += 1
	tomato_changed.emit(tomatoes)


## Spends one carried crop to plant a seed — never tomatoes (#36):
## tomatoes are lives, always == villagers.size(), and planting isn't a
## death condition.
func plant_crop() -> bool:
	return remove_item("crop", 1)


func add_plot(position: Vector2) -> int:
	var plot_id := _next_plot_id
	_next_plot_id += 1
	plots[plot_id] = position
	plot_placed.emit(plot_id, position)
	return plot_id


## Relocates an already-recorded plot in place — no new id, no refund.
func move_plot(plot_id: int, position: Vector2) -> void:
	plots[plot_id] = position


## Death already popped villagers down to 0 in lockstep with tomatoes
## (see lose_tomato) — respawning the starting roster restores both at
## once, rather than resetting `tomatoes` on its own (see #36).
func reset_run() -> void:
	villagers.clear()
	tomatoes = 0
	_spawn_starting_villagers()


## Equipping consumes one unit of the item from the counted inventory
## (so it stops also showing there), swapping any previous occupant of
## the slot back into the inventory first. No-ops if the item isn't
## owned, or is already equipped in its slot.
func equip_item(item_id: String) -> void:
	var data: ItemData = get_item_data(item_id)
	if not (data is EquipmentData) or get_item_count(item_id) <= 0:
		return
	var current_id: String = _equipped.get(data.slot, "")
	if current_id == item_id:
		return
	if current_id != "":
		add_item(current_id, 1)
	remove_item(item_id, 1)
	_equipped[data.slot] = item_id
	equipment_changed.emit(data.slot, item_id)


## Returns a slot's item to the counted inventory. No-op if the slot is
## empty.
func unequip_item(slot: EquipmentData.EquipSlot) -> void:
	var id: String = _equipped.get(slot, "")
	if id == "":
		return
	_equipped.erase(slot)
	add_item(id, 1)
	equipment_changed.emit(slot, "")


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
