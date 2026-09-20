extends StaticBody2D
## Crop storage chest: solid obstacle + interactable that opens the chest
## menu. Mirrors shop.gd's pattern exactly.

@onready var _interactable: InteractableComponent = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_interactable.player_out_of_range.connect(_on_player_out_of_range)


func _on_interacted() -> void:
	var chest_menu: Node = get_tree().get_first_node_in_group("chest_ui")
	if chest_menu:
		chest_menu.open()


func _on_player_out_of_range() -> void:
	var chest_menu: Node = get_tree().get_first_node_in_group("chest_ui")
	if chest_menu:
		chest_menu.close()
