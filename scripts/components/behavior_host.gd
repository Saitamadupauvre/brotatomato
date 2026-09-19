class_name BehaviorHost
extends Node
## Owns a set of Behavior children and dispatches named events to them.
## Any node type can host behaviors; InteractableComponent is the first,
## but this class carries no interaction-specific knowledge.

signal behavior_added(behavior: Behavior)
signal behavior_removed(behavior: Behavior)

## Path to the entity behaviors act on, relative to this host. Defaults to
## this host's parent; override when the host is nested deeper (e.g. Shop's
## Interactable/Host needs to point back up two levels to Shop itself).
@export var owner_entity_path: NodePath

var owner_entity: Node2D = null


func _ready() -> void:
	owner_entity = (get_node(owner_entity_path) if not owner_entity_path.is_empty() else get_parent()) as Node2D
	for child in get_children():
		if child is Behavior:
			child._setup(owner_entity, self)


func add_behavior(behavior: Behavior) -> void:
	add_child(behavior)
	behavior._setup(owner_entity, self)
	behavior_added.emit(behavior)


func remove_behavior(behavior: Behavior) -> void:
	behavior_removed.emit(behavior)
	remove_child(behavior)
	behavior.queue_free()


func broadcast(event_name: String, payload: Dictionary = {}) -> void:
	for child in get_children():
		if child is Behavior:
			child.on_event(event_name, payload)
