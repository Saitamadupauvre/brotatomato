extends MenuPanel
## Card shop dashboard (#7). Mirrors shop_menu.gd's pattern, but the offer
## grid is built from CardData resources (price + passive/active baked
## into the resource) rather than a static OFFERS dict, since a card's
## price is intrinsic to the card, not an assignment made at the shop.

const CARD_IDS: Array[String] = ["verdant_charm", "iron_fang", "swift_paws", "golden_touch"]

@onready var _grid: GridContainer = %ItemGrid


func _ready() -> void:
	super()
	add_to_group("card_shop_ui")
	_build_offer_cards()


func _build_offer_cards() -> void:
	var gold_icon: Texture2D = GameState.get_item_data("gold").icon
	for card_id in CARD_IDS:
		var card: CardData = GameState.get_item_data(card_id) as CardData
		_grid.add_child(_make_card(card, gold_icon))


func _make_card(card: CardData, gold_icon: Texture2D) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_card_gui_input.bind(card))
	panel.tooltip_text = "%s\nPassive: %s\nActive: %s" % [
		card.display_name, _passive_label(card), _active_label(card),
	]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.93, 0.78, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.texture = card.icon
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_rect)

	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.25, 0.18, 0.05))
	vbox.add_child(name_label)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(price_row)

	var price_icon := TextureRect.new()
	price_icon.texture = gold_icon
	price_icon.custom_minimum_size = Vector2(16, 16)
	price_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	price_icon.modulate = Color(1.0, 0.85, 0.2)
	price_row.add_child(price_icon)

	var price_label := Label.new()
	price_label.text = str(card.price)
	price_label.add_theme_color_override("font_color", Color(0.55, 0.42, 0.05))
	price_row.add_child(price_label)

	return panel


func _passive_label(card: CardData) -> String:
	var pct := "+%d%%" % int(card.passive_value * 100)
	match card.passive:
		CardData.Passive.PLOT_GROWTH_SPEED: return "%s plot growth speed" % pct
		CardData.Passive.PLAYER_DAMAGE: return "%s attack damage" % pct
		CardData.Passive.PLAYER_SPEED: return "%s move speed" % pct
		CardData.Passive.GOLD_GAIN: return "%s gold gained" % pct
		_: return "None"


func _active_label(card: CardData) -> String:
	match card.active:
		CardData.Active.INSTANT_HARVEST: return "Instant Harvest (ripen nearest plot)"
		CardData.Active.DAMAGE_BURST: return "Damage Burst (%d dmg nearby)" % int(card.active_value)
		CardData.Active.DASH_RESET: return "Dash Reset"
		CardData.Active.GOLD_RUSH: return "Gold Rush (+%d gold)" % int(card.active_value)
		_: return "None"


func _on_card_gui_input(event: InputEvent, card: CardData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_purchase(card)


func _try_purchase(card: CardData) -> void:
	if GameState.remove_item("gold", card.price):
		GameState.add_item(card.id, 1)
