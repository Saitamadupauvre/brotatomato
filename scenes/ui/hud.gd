class_name HUD
extends Control
## HUD: reads GameState via signals only, never mutates it. Exception:
## the dungeon scene calls setup_minimap() once per run to hand over
## the generated layout and player node, since that's per-run data with
## no natural GameState signal to read it from.

const FOG_REVEAL_RADIUS: int = 7

@onready var tomato_label: Label = %TomatoLabel
@onready var gold_label: Label = %GoldLabel
@onready var _minimap: MinimapDisplay = %Minimap
@onready var _map_overlay: MapOverlay = %MapOverlay
@onready var _ammo_stat: Control = %AmmoStat
@onready var _ammo_label: Label = %AmmoLabel
## Contextual crop/water indicators (#49) — only one shows at a time,
## whichever the closest in-range plot currently needs, standing in
## for "the item you'd have in hand" for that action.
@onready var _crop_stat: Control = %CropStat
@onready var _crop_label: Label = %CropLabel
@onready var _water_stat: Control = %WaterStat
@onready var _water_label: Label = %WaterLabel
## Bottom-right weapon hotbar (#50) — shows both weapon slots' icons and
## highlights whichever is active, so the "only the active weapon
## applies" rule from the acceptance criteria is visible mid-fight, not
## just in the inventory menu.
@onready var _weapon_slot_icons: Dictionary = {
	EquipmentData.EquipSlot.WEAPON: %WeaponSlot1Icon,
	EquipmentData.EquipSlot.WEAPON_2: %WeaponSlot2Icon,
}
@onready var _weapon_slot_panels: Dictionary = {
	EquipmentData.EquipSlot.WEAPON: %WeaponSlot1Panel,
	EquipmentData.EquipSlot.WEAPON_2: %WeaponSlot2Panel,
}

var _layout: DungeonLayout
var _player: CharacterBody2D
var _fog: FogOfWar


func _ready() -> void:
	GameState.tomato_changed.connect(_on_tomato_changed)
	GameState.item_changed.connect(_on_item_changed)
	_on_tomato_changed(GameState.tomatoes)
	_on_item_changed("gold", GameState.get_item_count("gold"))

	_ammo_stat.visible = false
	_crop_stat.visible = false
	_water_stat.visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.ammo_changed.connect(_on_ammo_changed)
		player.reload_started.connect(_on_reload_started)

	GameState.equipment_changed.connect(_on_weapon_equipment_changed)
	GameState.active_weapon_changed.connect(_on_active_weapon_changed)
	for slot in _weapon_slot_icons:
		_refresh_weapon_slot_icon(slot)
	_refresh_active_weapon_highlight()


func _process(_delta: float) -> void:
	_update_resource_prompt()

	if _layout == null or not is_instance_valid(_player):
		return
	var cell := _layout.world_to_cell(_player.position)
	_fog.reveal(cell, FOG_REVEAL_RADIUS)
	var facing: Vector2 = _player.velocity if _player.velocity.length() > 1.0 else Vector2.RIGHT
	_minimap.update_player(_player.position, facing)
	_map_overlay.update_player(_player.position, facing)


## Shows crop/water — whichever the closest in-range plot needs next —
## instead of always-on counters, so the HUD only surfaces the resource
## relevant to what the player is about to do (#49).
func _update_resource_prompt() -> void:
	var needed := ""
	var closest := InteractableComponent.get_closest_in_range()
	if closest:
		for child in closest.get_host().get_children():
			if child is PlotBehavior:
				needed = child.needed_item()
				break

	_crop_stat.visible = needed == "crop"
	_water_stat.visible = needed == "water"
	if needed == "crop":
		_crop_label.text = "%d" % GameState.get_item_count("crop")
	elif needed == "water":
		_water_label.text = "%d" % GameState.get_item_count("water")


## Called once by the dungeon scene after it builds the layout and
## places the player. No-op in Camp, which never calls it.
func setup_minimap(layout: DungeonLayout, player: CharacterBody2D) -> void:
	_layout = layout
	_player = player
	_fog = FogOfWar.new(layout.width, layout.height)
	_minimap.set_layout(layout)
	_minimap.set_fog(_fog)
	_map_overlay.set_layout(layout)
	_map_overlay.set_fog(_fog)
	_minimap.visible = true


func set_points_of_interest(pois: Array[MapPoi]) -> void:
	_minimap.set_points_of_interest(pois)
	_map_overlay.set_points_of_interest(pois)


func _on_tomato_changed(count: int) -> void:
	tomato_label.text = "%d" % count


func _on_item_changed(item_id: String, count: int) -> void:
	if item_id == "gold":
		gold_label.text = "%d" % count


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_ammo_stat.visible = max_ammo > 0
	_ammo_label.text = "%d/%d" % [current, max_ammo]


func _on_reload_started() -> void:
	_ammo_label.text = "Reloading..."


func _on_weapon_equipment_changed(slot: EquipmentData.EquipSlot, _item_id: String) -> void:
	if slot == EquipmentData.EquipSlot.WEAPON or slot == EquipmentData.EquipSlot.WEAPON_2:
		_refresh_weapon_slot_icon(slot)


func _on_active_weapon_changed(_slot: EquipmentData.EquipSlot) -> void:
	_refresh_active_weapon_highlight()


func _refresh_weapon_slot_icon(slot: EquipmentData.EquipSlot) -> void:
	var data: ItemData = GameState.get_equipped(slot)
	var icon: TextureRect = _weapon_slot_icons[slot]
	icon.texture = data.icon if data else null


const _ACTIVE_WEAPON_BORDER := Color(0.95, 0.8, 0.3, 1) # gold ring = active weapon slot


func _refresh_active_weapon_highlight() -> void:
	for slot in _weapon_slot_panels:
		var panel: PanelContainer = _weapon_slot_panels[slot]
		if slot == GameState.active_weapon_slot:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.22, 0.25, 0.85)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = _ACTIVE_WEAPON_BORDER
			style.set_corner_radius_all(8)
			panel.add_theme_stylebox_override("panel", style)
		else:
			panel.remove_theme_stylebox_override("panel")
