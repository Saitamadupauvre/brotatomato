extends MenuPanel
## Card gambling booth (#7): pay gold, roll a random card off a weighted
## LootTable (scripts/data/loot_table.gd — same resource ContainerBehavior
## already rolls for dungeon loot). No card-picking, purely a gamble.

const GAMBLE_COST: int = 50
const GAMBLE_LOOT_TABLE: LootTable = preload("res://resources/cards/card_gamble_loot.tres")

@onready var _gamble_button: Button = %GambleButton
@onready var _result_label: Label = %ResultLabel
@onready var _pool_row: HBoxContainer = %PoolRow


func _ready() -> void:
	super()
	add_to_group("card_shop_ui")
	_gamble_button.text = "Draw a card — %d gold" % GAMBLE_COST
	_gamble_button.pressed.connect(_on_gamble_pressed)
	UITheme.style_button(_gamble_button)
	_build_pool_preview()


## Hoverable preview of every card in the draw pool, so the player can
## check odds/abilities before spending gold.
func _build_pool_preview() -> void:
	for entry in GAMBLE_LOOT_TABLE.entries:
		var card: CardData = GameState.get_item_data(entry.item_id) as CardData
		if card == null:
			continue
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(52, 52)
		slot.add_theme_stylebox_override("panel", UITheme.slot_style(true))
		slot.tooltip_text = card.describe()
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

		var icon_rect := TextureRect.new()
		icon_rect.texture = card.icon
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_rect)
		_pool_row.add_child(slot)


func open() -> void:
	_result_label.text = ""
	super()


func _on_gamble_pressed() -> void:
	if not GameState.remove_item("gold", GAMBLE_COST):
		_result_label.text = "Not enough gold!"
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rolled: Array[LootEntry] = GAMBLE_LOOT_TABLE.roll(rng)
	if rolled.is_empty():
		_result_label.text = "..."
		return
	var card: CardData = GameState.get_item_data(rolled[0].item_id) as CardData
	GameState.add_item(rolled[0].item_id, rolled[0].amount)
	_result_label.text = "You got: %s\n%s\n%s" % [card.display_name, card.describe_passive(), card.describe_active()]
