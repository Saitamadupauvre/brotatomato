extends StaticBody2D
## Card shop entity (#7): solid obstacle + interactable that opens the
## card shop menu. Mirrors scripts/entities/shop.gd exactly, just against
## the "card_shop_ui" group instead of "shop_ui".

@onready var _interactable: InteractableComponent = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_interactable.player_out_of_range.connect(_on_player_out_of_range)


func _on_interacted() -> void:
	var menu: Node = get_tree().get_first_node_in_group("card_shop_ui")
	if menu:
		menu.open()


func _on_player_out_of_range() -> void:
	var menu: Node = get_tree().get_first_node_in_group("card_shop_ui")
	if menu:
		menu.close()
