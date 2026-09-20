extends Node
## Persistent cross-scene state. Single source of truth for anything that
## must survive a scene change. Only gameplay code (harvest/hit/death
## handlers) should call the mutators below — UI reads via signals.

## Item defs available to the inventory, keyed by ItemData.id once loaded.
## Add a new item: create its .tres in resources/items/, preload it here.
const ITEM_DEFS: Array[ItemData] = [
	preload("res://resources/items/gold.tres"),
	preload("res://resources/items/water.tres"),
	preload("res://resources/items/crop.tres"),
	preload("res://resources/items/dungeon_loot.tres"),
	preload("res://resources/items/ammo.tres"),
	preload("res://resources/items/key.tres"),
	preload("res://resources/equipment/sword.tres"),
	preload("res://resources/equipment/bow.tres"),
	preload("res://resources/equipment/dash_blade.tres"),
	preload("res://resources/equipment/pistol.tres"),
	preload("res://resources/equipment/leather_helmet.tres"),
	preload("res://resources/equipment/leather_chestplate.tres"),
	preload("res://resources/equipment/leather_leggings.tres"),
	preload("res://resources/equipment/leather_boots.tres"),
	preload("res://resources/cards/verdant_charm.tres"),
	preload("res://resources/cards/iron_fang.tres"),
	preload("res://resources/cards/swift_paws.tres"),
	preload("res://resources/cards/golden_touch.tres"),
]

signal tomato_changed(count: int)
signal life_lost(remaining: int, villager_names: Array[String])
signal player_died
signal player_won
signal villager_spawned(villager_id: int, position: Vector2, villager_name: String)
signal villager_removed(villager_id: int)
signal plot_placed(plot_id: int, position: Vector2)
signal item_changed(item_id: String, count: int)
signal equipment_changed(slot: EquipmentData.EquipSlot, item_id: String)
## Fired when the active weapon toggles between WEAPON/WEAPON_2 (#50) —
## distinct from equipment_changed, since swapping active slot changes
## which weapon is "in hand" without either slot's contents changing.
signal active_weapon_changed(slot: EquipmentData.EquipSlot)
signal breeding_started
signal card_equipped_changed(slot: int, item_id: String)
signal breeding_house_created(position: Vector2)

## TEMP: enough carried crop to seed the starting plots before the first
## harvest comes in. Remove/tune before ship.
const STARTING_CROP: int = 4
## TEMP: lets cards (#7) be bought/tested immediately without a full
## gold-farming loop first. Remove/tune before ship.
const STARTING_GOLD: int = 100

const CARD_SLOTS: int = 3

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

var _inventory: Dictionary = {} # item_id -> count
var _item_defs: Dictionary = {} # item_id -> ItemData
var _equipped: Dictionary = {} # EquipmentData.EquipSlot -> item_id
## Card (#7) loadout, index -> item_id ("" = empty slot). Equipping never
## consumes the owned copy (mirrors weapon/armor equip semantics).
var equipped_cards: Array[String] = ["", "", ""]
## Which weapon slot attacks currently draw from (#50). Only WEAPON or
## WEAPON_2 is ever valid here; toggled by swap_active_weapon().
var active_weapon_slot: EquipmentData.EquipSlot = EquipmentData.EquipSlot.WEAPON

## Positions of player-placed plots (beyond the 4 built-in ones), keyed by
## a stable id (not by position — floats round-tripped through a Node2D
## transform aren't guaranteed to compare equal), so they can be
## re-instantiated after Main is freed/reloaded by a scene change.
var plots: Dictionary = {} # plot_id -> Vector2

## Plot state/growth (#91 dungeon-trip bug): PlotBehavior itself is freed
## and reinstanced on every scene change, so it can't remember its own
## progress — GameState is the only thing alive across Camp <-> Dungeon.
## Keyed like `plots`; value is {state: PlotBehavior.PlotState, grow_end_unix: float}.
## grow_end_unix is an absolute Time.get_unix_time_from_system() timestamp
## so growth keeps counting down for real while the player is off in the
## dungeon, not just frozen and resumed.
var _plot_progress: Dictionary = {} # plot_id -> Dictionary

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

## Breeding House (#8): spends 2 lives to start, then grants a new one
## every BREEDING_INTERVAL seconds until the run ends. GDD doesn't fix a
## value for either — TEMP-tuned like PlotBehavior.grow_time.
const BREEDING_COST: int = 2
const BREEDING_INTERVAL: float = 20.0

## Breeding House creation (#87): gold cost, purchased like everything else
## in Camp — the materials/crafting loop was cut as out of scope. GDD
## doesn't fix a value — TEMP-tuned like BREEDING_COST.
const BREEDING_HOUSE_GOLD_COST: int = 50

var breeding_active: bool = false
var breeding_timer: float = 0.0
var breeding_house_position: Vector2 = Vector2.ZERO
## Whether the player has spent gold to place the Breeding House yet (#87)
## — it no longer exists in Camp until this is true, unlike the always
## -present Shop/Chest.
var breeding_house_placed: bool = false


func _ready() -> void:
	for item_data in ITEM_DEFS:
		_item_defs[item_data.id] = item_data
	add_item("crop", STARTING_CROP)
	add_item("gold", STARTING_GOLD)
	_spawn_starting_villagers()
	# TEMP: starting weapon so the held-item sprite (#47) has something to
	# show without going through the shop first. Remove/tune before ship.
	add_item("sword", 1)
	equip_item("sword")
	# TEMP: gun + reserve ammo in inventory for manual testing of #66/#67
	# (equip via the inventory drag-drop, not equipped by default). Remove
	# before ship.
	add_item("pistol", 1)
	add_item("ammo", 20)
	# TEMP: dash-strike weapon in inventory for manual testing of #65
	# (equip via inventory drag-drop, not equipped by default). Remove
	# before ship.
	add_item("dash_blade", 1)


func _process(delta: float) -> void:
	if not breeding_active:
		return
	breeding_timer -= delta
	if breeding_timer <= 0.0:
		breeding_timer += BREEDING_INTERVAL
		spawn_villager(breeding_house_position)


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
	## Golden Touch-style cards (#7) boost gold gain from any source —
	## hooked here rather than per-source since add_item is the single
	## place gold ever enters the inventory.
	if item_id == "gold" and amount > 0:
		amount = int(amount * get_passive_multiplier(CardData.Passive.GOLD_GAIN))
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


func can_create_breeding_house() -> bool:
	return not breeding_house_placed and get_item_count("gold") >= BREEDING_HOUSE_GOLD_COST


## Placement flow mirrors add_plot()'s data-first pattern (Main just
## reacts to the signal), but this is a one-shot singleton, not a
## dictionary of many — see breeding_house_placed.
func create_breeding_house(position: Vector2) -> bool:
	if not can_create_breeding_house():
		return false
	if not remove_item("gold", BREEDING_HOUSE_GOLD_COST):
		return false
	breeding_house_placed = true
	breeding_house_position = position
	breeding_house_created.emit(position)
	return true


func can_start_breeding() -> bool:
	return not breeding_active and tomatoes >= BREEDING_COST


## Spends villager_ids as the breeding cost (#8) — a deliberate life spend,
## same lockstep removal as lose_tomato() but by specific id (the caller
## already walked these exact villagers to the house) rather than
## pop_back, and no life_lost signal (that's combat-flavored, only
## dungeon.gd listens for it).
func start_breeding(villager_ids: Array[int], house_position: Vector2) -> void:
	for id in villager_ids:
		for i in villagers.size():
			if villagers[i]["id"] == id:
				villagers.remove_at(i)
				villager_removed.emit(id)
				break
	tomatoes = max(tomatoes - villager_ids.size(), 0)
	tomato_changed.emit(tomatoes)
	if tomatoes <= 0:
		player_died.emit()
	breeding_active = true
	breeding_timer = BREEDING_INTERVAL
	breeding_house_position = house_position
	breeding_started.emit()


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


## Called by PlotBehavior on every state change so its progress survives
## the scene reload it doesn't survive itself (#91).
func set_plot_progress(plot_id: int, state: int, grow_end_unix: float) -> void:
	_plot_progress[plot_id] = {"state": state, "grow_end_unix": grow_end_unix}


## Empty dict if the plot has never seen a state change (fresh plot).
func get_plot_progress(plot_id: int) -> Dictionary:
	return _plot_progress.get(plot_id, {})


## Death already popped villagers down to 0 in lockstep with tomatoes
## (see lose_tomato) — respawning the starting roster restores both at
## once, rather than resetting `tomatoes` on its own (see #36).
## Fired by the final-boss altar on its wave_cleared — see AltarBehavior.is_final_boss.
func win_game() -> void:
	player_won.emit()


func reset_run() -> void:
	villagers.clear()
	tomatoes = 0
	breeding_active = false
	breeding_timer = 0.0
	breeding_house_placed = false
	breeding_house_position = Vector2.ZERO
	plots.clear()
	_plot_progress.clear()
	_spawn_starting_villagers()


## Equipping consumes one unit of the item from the counted inventory
## (so it stops also showing there), swapping any previous occupant of
## the slot back into the inventory first. No-ops if the item isn't
## owned, or is already equipped in its slot.
## target_slot lets a weapon land in WEAPON or WEAPON_2 (#50) — both
## accept the same items (weapon resources are always authored with
## data.slot == WEAPON), so which physical slot it fills can't be read
## off the item itself. Defaults to data.slot, which is correct for
## armor (single slot per piece) and for equipping a weapon with no
## explicit target (falls into WEAPON).
func equip_item(item_id: String, target_slot: int = -1) -> void:
	var data: ItemData = get_item_data(item_id)
	if not (data is EquipmentData) or get_item_count(item_id) <= 0:
		return
	var slot: int = target_slot if target_slot != -1 else data.slot
	var current_id: String = _equipped.get(slot, "")
	if current_id == item_id:
		return
	if current_id != "":
		add_item(current_id, 1)
	remove_item(item_id, 1)
	_equipped[slot] = item_id
	equipment_changed.emit(slot, item_id)


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


## Card (#7) equip, mirroring equip_item's consume-from-inventory
## semantics: the slot's previous occupant (if any) is returned to the
## counted inventory, the new one is removed from it.
func equip_card(item_id: String, slot: int) -> void:
	var data: ItemData = get_item_data(item_id)
	if not (data is CardData) or get_item_count(item_id) <= 0:
		return
	if slot < 0 or slot >= CARD_SLOTS:
		return
	var current_id: String = equipped_cards[slot]
	if current_id == item_id:
		return
	if current_id != "":
		add_item(current_id, 1)
	remove_item(item_id, 1)
	equipped_cards[slot] = item_id
	card_equipped_changed.emit(slot, item_id)


func unequip_card(slot: int) -> void:
	if slot < 0 or slot >= CARD_SLOTS:
		return
	var id: String = equipped_cards[slot]
	if id == "":
		return
	equipped_cards[slot] = ""
	add_item(id, 1)
	card_equipped_changed.emit(slot, "")


## 1.0 + sum of passive_value across equipped cards matching `passive` —
## consumers (PlotBehavior, Player, add_item's gold hook) just read this,
## no card-specific branching outside GameState.
func get_passive_multiplier(passive: CardData.Passive) -> float:
	var multiplier: float = 1.0
	for item_id in equipped_cards:
		if item_id == "":
			continue
		var card := get_item_data(item_id) as CardData
		if card and card.passive == passive:
			multiplier += card.passive_value
	return multiplier


## Toggles which weapon slot attacks draw from (#50). Swaps even to an
## empty slot (going unarmed is a valid, if bad, choice) rather than
## refusing — a player should always be able to tell what "switch
## weapon" did without a silent no-op.
func swap_active_weapon() -> void:
	active_weapon_slot = EquipmentData.EquipSlot.WEAPON_2 \
		if active_weapon_slot == EquipmentData.EquipSlot.WEAPON \
		else EquipmentData.EquipSlot.WEAPON
	active_weapon_changed.emit(active_weapon_slot)


func get_active_weapon() -> ItemData:
	return get_equipped(active_weapon_slot)
