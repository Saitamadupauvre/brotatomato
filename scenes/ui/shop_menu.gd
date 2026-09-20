extends MenuPanel
## Shop dashboard. Grid built at runtime from OFFERS — clicking an "item"
## card spends gold and grants the item; clicking an "action" card spends
## no gold itself but hands off to the matching placement controller
## (Plot/Breeding House), which spends gold once the player confirms a
## spot, same as pressing its hotkey directly.

const PLOT_ICON: Texture2D = preload("res://assets/sprites/tomato/dirt.png")
const BREEDING_HOUSE_ICON: Texture2D = preload("res://assets/sprites/props/breeding_house.png")

const OFFERS: Array[Dictionary] = [
	{"type": "item", "item_id": "water", "price": 5},
	{"type": "item", "item_id": "sword", "price": 40},
	{"type": "item", "item_id": "bow", "price": 50},
	{"type": "action", "action": "plot", "display_name": "Plot", "icon": PLOT_ICON, "price": PlotPlacementController.GOLD_COST},
	{"type": "action", "action": "breeding_house", "display_name": "Breeding House", "icon": BREEDING_HOUSE_ICON, "price": GameState.BREEDING_HOUSE_GOLD_COST},
]

@onready var _grid: GridContainer = %ItemGrid


func _ready() -> void:
	super()
	add_to_group("shop_ui")
	_build_offer_cards()


func _build_offer_cards() -> void:
	var gold_icon: Texture2D = GameState.get_item_data("gold").icon
	for offer in OFFERS:
		# Breeding House is a one-shot purchase; drop its card once built.
		if offer.get("action") == "breeding_house" and GameState.breeding_house_placed:
			continue
		var display_name: String
		var icon: Texture2D
		if offer["type"] == "item":
			var item_data: ItemData = GameState.get_item_data(offer["item_id"])
			display_name = item_data.display_name
			icon = item_data.icon
		else:
			display_name = offer["display_name"]
			icon = offer["icon"]
		_grid.add_child(_make_card(display_name, icon, offer, gold_icon))


func _make_card(display_name: String, icon: Texture2D, offer: Dictionary, gold_icon: Texture2D) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_gui_input.bind(offer))
	var style := UITheme.slot_style(true)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.25, 0.18, 0.05))
	vbox.add_child(name_label)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(price_row)

	var price_icon := TextureRect.new()
	price_icon.texture = gold_icon
	price_icon.custom_minimum_size = Vector2(16, 16)
	price_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	price_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	price_icon.modulate = Color(1.0, 0.85, 0.2)
	price_row.add_child(price_icon)

	var price_label := Label.new()
	price_label.text = str(offer["price"])
	price_label.add_theme_color_override("font_color", Color(0.55, 0.42, 0.05))
	price_row.add_child(price_label)

	return card


func _on_card_gui_input(event: InputEvent, offer: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_purchase(offer)


func _try_purchase(offer: Dictionary) -> void:
	if offer["type"] == "item":
		if GameState.remove_item("gold", offer["price"]):
			GameState.add_item(offer["item_id"], 1)
		return
	# Action offers don't spend gold here — closing the shop hands off to
	# the placement controller, which spends it once a spot is confirmed.
	close()
	match offer["action"]:
		"plot":
			get_tree().get_first_node_in_group("plot_placement").start_placing()
		"breeding_house":
			get_tree().get_first_node_in_group("breeding_house_placement").start_placing()
