class_name FlyingFlapBehavior
extends Behavior
## Alternates the enemy's Sprite texture between two frames on a timer to
## fake a fast wing-flap — used by the flying (dash) enemy variants.

@export var frame_a: Texture2D
@export var frame_b: Texture2D
@export var flap_interval: float = 0.08

var _timer: float = 0.0
var _showing_a: bool = true
var _sprite: Sprite2D = null


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_sprite = owner_entity.get_node("Sprite") as Sprite2D


func on_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name != "physics_tick" or _sprite == null:
		return
	_timer -= payload.get("delta", 0.0)
	if _timer <= 0.0:
		_timer = flap_interval
		_showing_a = not _showing_a
		_sprite.texture = frame_a if _showing_a else frame_b
