extends MenuPanel
## Card gambling booth (#7): pay gold, roll a random card off a weighted
## LootTable (scripts/data/loot_table.gd — same resource ContainerBehavior
## already rolls for dungeon loot). No card-picking, purely a gamble.

const GAMBLE_COST: int = 50
const GAMBLE_LOOT_TABLE: LootTable = preload("res://resources/cards/card_gamble_loot.tres")

@onready var _gamble_button: Button = %GambleButton
@onready var _result_label: Label = %ResultLabel


func _ready() -> void:
	super()
	add_to_group("card_shop_ui")
	_gamble_button.text = "Draw a card — %d gold" % GAMBLE_COST
	_gamble_button.pressed.connect(_on_gamble_pressed)


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
	_result_label.text = "You got: %s!" % card.display_name
