class_name PromptBehavior
extends Behavior
## Shows/hides a world-space "press E" prompt above the owner entity when
## the player is nearby. Only reacts to named events, entity-agnostic.

@export var label_text: String = "E"
@export var offset: Vector2 = Vector2(0, -48)

var _label: Label = null


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_label = Label.new()
	_label.text = label_text
	_label.position = offset
	_label.visible = false
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Built during BehaviorHost._ready(), while the scene tree is still
	# busy setting up children — add_child must be deferred.
	owner_entity.add_child.call_deferred(_label)


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	match event_name:
		"player_in_range":
			_label.visible = true
		"player_out_of_range":
			_label.visible = false
