class_name OutlineBehavior
extends Behavior
## Toggles an outline on the owner entity's sprite when the player is
## nearby. Uses OutlineVisual (duplicate, tint, enlarge, draw behind) —
## no shader, works for both Control and Node2D sprite placeholders.

@export var sprite_path: NodePath
@export var outline_color: Color = Color(1.0, 0.9, 0.2, 1.0)
@export var outline_margin: float = 6.0 # growth in px, for Control sprites
@export var outline_scale: float = 1.2 # growth factor, for Node2D sprites

var _outline: CanvasItem = null


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	var sprite: CanvasItem = owner_entity.get_node(sprite_path)
	_outline = OutlineVisual.create(sprite, outline_color, outline_margin, outline_scale)


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	match event_name:
		"player_in_range":
			_outline.visible = true
		"player_out_of_range":
			_outline.visible = false
