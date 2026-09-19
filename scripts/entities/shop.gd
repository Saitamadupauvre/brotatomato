extends StaticBody2D
## Shop entity: solid obstacle + interactable that opens the shop menu.
## All proximity/outline/prompt behavior lives in the Interactable child;
## this script only reacts to the one signal it cares about.

@onready var _interactable: InteractableComponent = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var shop_menu: Node = get_tree().get_first_node_in_group("shop_ui")
	if shop_menu:
		shop_menu.open()
