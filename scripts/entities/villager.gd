class_name Villager
extends CharacterBody2D
## Idle-then-wander AI: picks a random direction, moves for a bit, then
## pauses, repeating forever within camp bounds (clamped by wall collision,
## same as Player/Enemy). Visual-only entity — no role yet (see CLAUDE.md).

@export var move_speed: float = 60.0
@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0
@export var min_move_time: float = 1.0
@export var max_move_time: float = 2.5

var _state_timer: float = 0.0
var _is_moving: bool = false


func _ready() -> void:
	_enter_idle()


func _physics_process(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		if _is_moving:
			_enter_idle()
		else:
			_enter_move()

	move_and_slide()


func _enter_idle() -> void:
	_is_moving = false
	velocity = Vector2.ZERO
	_state_timer = randf_range(min_idle_time, max_idle_time)


func _enter_move() -> void:
	_is_moving = true
	velocity = Vector2.from_angle(randf() * TAU) * move_speed
	_state_timer = randf_range(min_move_time, max_move_time)
