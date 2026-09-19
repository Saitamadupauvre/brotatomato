class_name Behavior
extends Node
## Base for all attachable behaviors. A BehaviorHost adds these as children
## and dispatches named events to them — a behavior never assumes what kind
## of entity or host it's attached to, only the event contract.

var owner_entity: Node2D = null
var host: BehaviorHost = null


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	owner_entity = p_owner
	host = p_host


## Overridden per behavior. Called by the host's broadcast().
func on_event(_event_name: String, _payload: Dictionary = {}) -> void:
	pass
