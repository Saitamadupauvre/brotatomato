extends MenuPanel
## Inventory dashboard, Minecraft-style layout: vertical armor column,
## player portrait, weapon slot off to the side, fixed-size item grid
## below (empty slots shown, not just owned items). Reads GameState
## only; cards are icon + count badge, hover shows the name via Godot's
## built-in tooltip. Clicking an equipment card equips it.

const TOTAL_SLOTS: int = 12

@onready var _grid: GridContainer = %InventoryGrid
@onready var _slot_rects: Dictionary = {
	EquipmentData.EquipSlot.WEAPON: %WeaponSlot,
	EquipmentData.EquipSlot.HELMET: %HelmetSlot,
	EquipmentData.EquipSlot.CHESTPLATE: %ChestplateSlot,
	EquipmentData.EquipSlot.LEGGINGS: %LeggingsSlot,
	EquipmentData.EquipSlot.BOOTS: %BootsSlot,
}


func _ready() -> void:
	super()
	GameState.equipment_changed.connect(_on_equipment_changed)
	for slot in EquipmentData.ALL_SLOTS:
		_refresh_slot(slot)


func _input(event: InputEvent) -> void:
	super(event)
	if event.is_action_pressed("toggle_inventory"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	show()


func _on_equipment_changed(slot: EquipmentData.EquipSlot, _item_id: String) -> void:
	_refresh_slot(slot)


func _refresh_slot(slot: EquipmentData.EquipSlot) -> void:
	var data: ItemData = GameState.get_equipped(slot)
	var slot_rect: TextureRect = _slot_rects[slot]
	slot_rect.texture = data.icon if data else null


func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var owned_ids: Array = []
	for item_id in GameState.get_all_item_ids():
		if GameState.get_item_count(item_id) > 0:
			owned_ids.append(item_id)

	for i in TOTAL_SLOTS:
		if i < owned_ids.size():
			var item_id: String = owned_ids[i]
			_grid.add_child(_make_card(GameState.get_item_data(item_id), GameState.get_item_count(item_id)))
		else:
			_grid.add_child(_make_empty_slot())


func _make_empty_slot() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(56, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.2, 0.24, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.34, 0.4, 1.0)
	style.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", style)
	return slot


func _make_card(item_data: ItemData, count: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(56, 56)
	card.tooltip_text = item_data.display_name
	if item_data is EquipmentData:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_gui_input.bind(item_data.id))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.26, 0.32, 1.0)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var icon_rect := TextureRect.new()
	icon_rect.texture = item_data.icon
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon_rect)

	var badge := Label.new()
	badge.text = str(count)
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(1, 1, 1))
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0, 0, 0, 0.6)
	badge_style.set_corner_radius_all(4)
	badge_style.content_margin_left = 4
	badge_style.content_margin_right = 4
	badge.add_theme_stylebox_override("normal", badge_style)
	card.add_child(badge)

	return card


func _on_card_gui_input(event: InputEvent, item_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.equip_item(item_id)
