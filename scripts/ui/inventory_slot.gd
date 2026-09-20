class_name InventorySlot
extends Control
## Click-to-pick-up / click-to-place slot (Minecraft-style), shared by
## inventory grid cells and equip slot rects. This node only reports
## clicks — InventoryMenu is the coordinator holding the "item in hand"
## state and deciding what a click means (pick up, place, swap, cancel).
## `equip_slot` of -1 means a generic inventory cell (accepts anything);
## any other value is an EquipmentData.EquipSlot the menu only allows a
## matching item to be placed into.

signal clicked(slot: InventorySlot)

var item_id: String = ""
var equip_slot: int = -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()
