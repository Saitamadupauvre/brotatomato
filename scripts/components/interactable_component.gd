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
var _player_ref: Node2D = null

## Every Interactable currently in range of the player, shared across all
## instances — used so one E press resolves to the single closest one
## instead of broadcasting to every overlapping detection circle at once.
static var _in_range: Array[InteractableComponent] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	_in_range.erase(self)


func _unhandled_input(event: InputEvent) -> void:
	if not disabled and _player_nearby and event.is_action_pressed("interact"):
		if self != _closest_in_range():
			return
		_host.broadcast("interacted")
		interacted.emit()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if disabled:
		return
	if body.is_in_group("player"):
		_player_nearby = true
		_player_ref = body
		_in_range.append(self)
		_host.broadcast("player_in_range")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_in_range.erase(self)
		_host.broadcast("player_out_of_range")
		player_out_of_range.emit()


func _closest_in_range() -> InteractableComponent:
	var closest: InteractableComponent = null
	var closest_distance: float = INF
	for candidate in _in_range:
		var distance: float = candidate.global_position.distance_squared_to(candidate._player_ref.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest
