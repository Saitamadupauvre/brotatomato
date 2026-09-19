class_name ItemPickup
extends Area2D
## World-space dropped item. Auto-collects on player touch, unlike the
## E-press Interactable pattern — thrown loot is meant to be walked over.
## item_id/amount are set by whatever spawns this (see ContainerBehavior),
## not authored in the inspector.

@export var float_amplitude: float = 3.0
@export var float_speed: float = 4.0

var item_id: String = ""
var amount: int = 1

@onready var _sprite: CanvasItem = $Sprite

var _floating: bool = false
var _float_time: float = 0.0
var _float_base_y: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _floating:
		_float_time += delta
		_sprite.position.y = _float_base_y + sin(_float_time * float_speed) * float_amplitude


## Tweens to target_position instead of teleporting, then starts a gentle
## idle bob once landed.
func toss_to(target_position: Vector2, duration: float = 0.35) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, duration)
	tween.finished.connect(_start_floating)


func _start_floating() -> void:
	_floating = true
	_float_base_y = _sprite.position.y


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameState.add_item(item_id, amount)
		queue_free()
