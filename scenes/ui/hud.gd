extends Control
## HUD: reads GameState via signals only, never mutates it.

@onready var tomato_label: Label = %TomatoLabel
@onready var gold_label: Label = %GoldLabel


func _ready() -> void:
	GameState.tomato_changed.connect(_on_tomato_changed)
	GameState.item_changed.connect(_on_item_changed)
	_on_tomato_changed(GameState.tomatoes)
	_on_item_changed("gold", GameState.get_item_count("gold"))


func _on_tomato_changed(count: int) -> void:
	tomato_label.text = "%d" % count


func _on_item_changed(item_id: String, count: int) -> void:
	if item_id == "gold":
		gold_label.text = "%d" % count
