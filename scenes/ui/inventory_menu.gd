extends MenuPanel
## Inventory dashboard, Minecraft-style layout: vertical armor column,
## player portrait, weapon slot off to the side, fixed-size item grid
## below (empty slots shown, not just owned items). Reads GameState
## only. Equipping/moving items is click-to-pick-up, click-to-place:
## click a slot to lift its item (it follows the cursor), click another
## slot to drop it there — swapping with whatever's already in that
## slot, or clicking the origin again to cancel. See InventorySlot.

const TOTAL_SLOTS: int = 12

const _SLOT_SCRIPT := preload("res://scripts/ui/inventory_slot.gd")

## Display order of the grid, item_id per cell ("" = empty). Purely a UI
## arrangement, independent from GameState's count-based inventory —
## lets picking up a card and placing it on another cell reorder/swap
## without changing what's owned.
var _slot_order: Array = []

var _held_item_id: String = ""
var _held_origin: InventorySlot = null
var _held_icon: TextureRect = null

@onready var _grid: GridContainer = %InventoryGrid
@onready var _slot_rects: Dictionary = {
	EquipmentData.EquipSlot.WEAPON: %WeaponSlot,
	EquipmentData.EquipSlot.WEAPON_2: %WeaponSlot2,
	EquipmentData.EquipSlot.HELMET: %HelmetSlot,
	EquipmentData.EquipSlot.CHESTPLATE: %ChestplateSlot,
	EquipmentData.EquipSlot.LEGGINGS: %LeggingsSlot,
	EquipmentData.EquipSlot.BOOTS: %BootsSlot,
}
## Weapon slots' own panel (parent of the TextureRect), highlighted to
## show which one attacks currently draw from (#50) — armor slots have
## no such concept, so only these two are tracked.
@onready var _weapon_slot_panels: Dictionary = {
	EquipmentData.EquipSlot.WEAPON: %WeaponSlot.get_parent(),
	EquipmentData.EquipSlot.WEAPON_2: %WeaponSlot2.get_parent(),
}
## Card (#7) loadout slots, index -> InventorySlot, parallel to _slot_rects.
@onready var _card_slot_rects: Array = [%CardSlot1, %CardSlot2, %CardSlot3]


func _ready() -> void:
	super()
	_slot_order.resize(TOTAL_SLOTS)
	_slot_order.fill("")
	GameState.equipment_changed.connect(_on_equipment_changed)
	GameState.active_weapon_changed.connect(_on_active_weapon_changed)
	GameState.card_equipped_changed.connect(_on_card_equipped_changed)
	for slot in EquipmentData.ALL_SLOTS:
		var slot_rect = _slot_rects[slot]
		slot_rect.equip_slot = slot
		slot_rect.clicked.connect(_on_slot_clicked)
		_refresh_slot(slot)
	for i in _card_slot_rects.size():
		var card_slot_rect = _card_slot_rects[i]
		card_slot_rect.card_slot_index = i
		card_slot_rect.clicked.connect(_on_slot_clicked)
		_refresh_card_slot(i)
	_refresh_active_weapon_highlight()


func _input(event: InputEvent) -> void:
	super(event)
	if event.is_action_pressed("toggle_inventory"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _held_icon:
		# Re-forced every frame: a TextureRect with no Container parent has
		# nothing else re-applying its size after the initial assignment,
		# and previously that one assignment wasn't enough to stop it
		# rendering at its source texture's full native resolution.
		_held_icon.size = _HELD_ICON_SIZE
		_held_icon.global_position = get_global_mouse_position() - _HELD_ICON_SIZE / 2.0


func open() -> void:
	_refresh()
	show()


func _on_equipment_changed(slot: EquipmentData.EquipSlot, _item_id: String) -> void:
	_refresh_slot(slot)


func _on_active_weapon_changed(_slot: EquipmentData.EquipSlot) -> void:
	_refresh_active_weapon_highlight()


func _refresh_active_weapon_highlight() -> void:
	for slot in _weapon_slot_panels:
		var panel: PanelContainer = _weapon_slot_panels[slot]
		if slot == GameState.active_weapon_slot:
			panel.add_theme_stylebox_override("panel", UITheme.highlight_style())
		else:
			panel.remove_theme_stylebox_override("panel")


func _refresh_slot(slot: EquipmentData.EquipSlot) -> void:
	var data: ItemData = GameState.get_equipped(slot)
	var slot_rect = _slot_rects[slot]
	slot_rect.texture = data.icon if data else null
	slot_rect.item_id = data.id if data else ""


func _on_card_equipped_changed(slot: int, _item_id: String) -> void:
	_refresh_card_slot(slot)


func _refresh_card_slot(slot: int) -> void:
	var item_id: String = GameState.equipped_cards[slot]
	var data: CardData = GameState.get_item_data(item_id) as CardData
	var slot_rect = _card_slot_rects[slot]
	slot_rect.texture = data.icon if data else null
	slot_rect.item_id = data.id if data else ""
	slot_rect.tooltip_text = data.describe() if data else ""


func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	_sync_slot_order()

	for i in _slot_order.size():
		var item_id: String = _slot_order[i]
		var slot
		if item_id != "":
			slot = _make_card(GameState.get_item_data(item_id), GameState.get_item_count(item_id))
		else:
			slot = _make_empty_slot()
		slot.set_meta("grid_index", i)
		slot.clicked.connect(_on_slot_clicked)
		_grid.add_child(slot)


## Keeps _slot_order in step with what's actually owned: drops entries
## whose count hit 0, then places any newly-owned item into the first
## free cell. Existing positions are left untouched so a manual reorder
## survives a refresh.
func _sync_slot_order() -> void:
	for i in _slot_order.size():
		var id: String = _slot_order[i]
		if id != "" and GameState.get_item_count(id) <= 0:
			_slot_order[i] = ""

	for item_id in GameState.get_all_item_ids():
		if GameState.get_item_count(item_id) <= 0 or _slot_order.has(item_id):
			continue
		var empty_index: int = _slot_order.find("")
		if empty_index != -1:
			_slot_order[empty_index] = item_id


func _on_slot_clicked(slot: InventorySlot) -> void:
	if _held_item_id == "":
		_try_pick_up(slot)
	else:
		_try_place(slot)


func _try_pick_up(slot: InventorySlot) -> void:
	if slot.item_id == "":
		return
	_held_item_id = slot.item_id
	_held_origin = slot
	slot.modulate.a = 0.35
	_show_held_icon(GameState.get_item_data(_held_item_id).icon)


func _try_place(target: InventorySlot) -> void:
	if target == _held_origin:
		_cancel_hold()
		return

	if target.equip_slot != -1:
		if not _item_fits_equip_slot(_held_item_id, target.equip_slot):
			return
		GameState.equip_item(_held_item_id, target.equip_slot)
	elif _held_origin.equip_slot != -1:
		GameState.unequip_item(_held_origin.equip_slot)
	elif target.card_slot_index != -1:
		if not (GameState.get_item_data(_held_item_id) is CardData):
			return
		GameState.equip_card(_held_item_id, target.card_slot_index)
	elif _held_origin.card_slot_index != -1:
		GameState.unequip_card(_held_origin.card_slot_index)
	else:
		_swap_grid_slots(_held_origin, target)

	_finish_hold()


## WEAPON_2 accepts the same items as WEAPON — weapon resources are always
## authored with data.slot == WEAPON (#50); WEAPON_2 is a second physical
## slot, not a distinct item category.
func _item_fits_equip_slot(item_id: String, slot: int) -> bool:
	var data: ItemData = GameState.get_item_data(item_id)
	if not (data is EquipmentData):
		return false
	if slot == EquipmentData.EquipSlot.WEAPON_2:
		return data.slot == EquipmentData.EquipSlot.WEAPON
	return data.slot == slot


func _swap_grid_slots(origin: InventorySlot, target: InventorySlot) -> void:
	var i: int = origin.get_meta("grid_index", -1)
	var j: int = target.get_meta("grid_index", -1)
	if i == -1 or j == -1 or i == j:
		return
	var tmp: String = _slot_order[i]
	_slot_order[i] = _slot_order[j]
	_slot_order[j] = tmp


func _cancel_hold() -> void:
	_held_origin.modulate.a = 1.0
	_clear_held_icon()
	_held_item_id = ""
	_held_origin = null


func _finish_hold() -> void:
	_clear_held_icon()
	_held_item_id = ""
	_held_origin = null
	_refresh()


## Card icons are 48px (see _make_card); held icon reads a bit bigger
## (56px) to read as "lifted", using custom_minimum_size rather than
## .size directly — a bare TextureRect with no container to constrain it
## otherwise renders at its source texture's native size.
const _HELD_ICON_SIZE := Vector2(56, 56)


func _show_held_icon(texture: Texture2D) -> void:
	_held_icon = TextureRect.new()
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.custom_minimum_size = _HELD_ICON_SIZE
	_held_icon.texture = texture
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.modulate.a = 0.9
	add_child(_held_icon)
	_held_icon.size = _HELD_ICON_SIZE
	_held_icon.global_position = get_global_mouse_position() - _HELD_ICON_SIZE / 2.0


func _clear_held_icon() -> void:
	if _held_icon:
		_held_icon.queue_free()
		_held_icon = null


## Untyped return: the node stays natively a PanelContainer with
## InventorySlot attached via set_script, and GDScript's static "as"
## cast rejects that (native type unrelated to InventorySlot's own
## "extends Control") even though the runtime script is correct.
func _make_slot_shell():
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(88, 88)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.set_script(_SLOT_SCRIPT)
	return slot


func _make_empty_slot():
	var slot = _make_slot_shell()
	slot.add_theme_stylebox_override("panel", UITheme.slot_style(false))
	return slot


func _make_card(item_data: ItemData, count: int):
	var card = _make_slot_shell()
	card.tooltip_text = item_data.describe() if item_data is CardData else item_data.display_name
	card.item_id = item_data.id
	card.add_theme_stylebox_override("panel", UITheme.slot_style(true))

	# PanelContainer forces a full-rect layout on any direct Container
	# child, so a plain (non-Container) Control bridges here — its own
	# children keep manual anchors, letting the badge sit in a corner
	# instead of being stretched to fill the whole slot.
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(content)

	var icon_rect := TextureRect.new()
	icon_rect.texture = item_data.icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(icon_rect)

	# Built and populated *before* being anchored: set_anchors_and_offsets_
	# preset(..., PRESET_MODE_MINSIZE, ...) reads the control's current
	# minimum size to place it, so anchoring an empty panel first (its
	# minimum size still 0x0 with no label child yet) previously placed the
	# badge's origin outside the slot's visible box.
	var badge_panel := PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = UITheme.PANEL_BORDER
	badge_style.set_corner_radius_all(4)
	badge_style.content_margin_left = 4
	badge_style.content_margin_right = 4
	badge_style.content_margin_top = 1
	badge_style.content_margin_bottom = 1
	badge_panel.add_theme_stylebox_override("panel", badge_style)

	var badge := Label.new()
	badge.text = str(count)
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", UITheme.BUTTON_TEXT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(badge)

	content.add_child(badge_panel)
	badge_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 2)

	return card
