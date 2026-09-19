class_name ItemData
extends Resource
## Schema for one inventory item type. Instances live as .tres in
## resources/items/ — new items are "duplicate a .tres, tweak fields."

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = -1 # -1 = unlimited
