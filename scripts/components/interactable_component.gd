class_name InteractableComponent
extends Area2D
## Reusable "can be interacted with" component. Detects the player via the
## "player" group, broadcasts proximity/interact events to a BehaviorHost
## child (see behavior_host.gd), and emits `interacted` for the owning
## entity (Shop, a future chest/NPC, ...) to react to directly.
##
## Drop this scene as a child of any entity, wire the Host's owner_entity
## export to that entity, and add Behavior children (OutlineBehavior,
## PromptBehavior, ...) under the Host to react to proximity/interact
## without any of them knowing what kind of entity they're attached to.

signal interacted
signal player_out_of_range

## Set by OpenedStateBehavior once the entity has nothing left to give —
## stops all further proximity/interact broadcasts for good.
var disabled: bool = false

@onready var _host: BehaviorHost = $Host

var _player_nearby: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not disabled and _player_nearby and event.is_action_pressed("interact"):
		_host.broadcast("interacted")
		interacted.emit()


func _on_body_entered(body: Node2D) -> void:
	if disabled:
		return
	if body.is_in_group("player"):
		_player_nearby = true
		_host.broadcast("player_in_range")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_host.broadcast("player_out_of_range")
		player_out_of_range.emit()
