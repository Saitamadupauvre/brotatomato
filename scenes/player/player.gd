extends CharacterBody2D

@export var speed: float = 250.0
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _last_move_direction: Vector2 = Vector2.DOWN


func _physics_process(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta

	if _is_dashing:
		_process_dash(delta)
	else:
		_process_movement()

	move_and_slide()


func _process_movement() -> void:
	var input_direction := _get_input_direction()

	if input_direction != Vector2.ZERO:
		_last_move_direction = input_direction

	velocity = input_direction * speed

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_start_dash(input_direction)


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity = _dash_direction * dash_speed

	if _dash_timer <= 0.0:
		_is_dashing = false


func _start_dash(input_direction: Vector2) -> void:
	_dash_direction = input_direction if input_direction != Vector2.ZERO else _last_move_direction
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown


func _get_input_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
