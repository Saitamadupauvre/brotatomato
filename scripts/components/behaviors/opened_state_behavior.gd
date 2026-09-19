class_name OpenedStateBehavior
extends Behavior
## Marks an entity as permanently "opened" once whatever it gives out is
## spent (chest loot, altar wave reward): hides outline/prompt, disables
## further interaction, drops collision, and dims the sprite. Drop this
## as a sibling of ContainerBehavior/AltarBehavior under the same Host —
## they broadcast `trigger_event` once their own state settles into "done".

@export var trigger_event: String = "contents_emptied"
@export var sprite_path: NodePath
@export var opened_modulate: Color = Color(0.45, 0.45, 0.45, 1.0)


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name != trigger_event:
		return
	host.broadcast("player_out_of_range")
	var interactable := host.get_parent() as InteractableComponent
	if interactable != null:
		interactable.disabled = true
	var body := owner_entity as CollisionObject2D
	if body != null:
		body.collision_layer = 0
	if not sprite_path.is_empty():
		var sprite: CanvasItem = owner_entity.get_node_or_null(sprite_path)
		if sprite != null:
			sprite.modulate = opened_modulate
