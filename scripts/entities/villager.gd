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
@export var squash_speed: float = 8.0 # squash cycles per second while moving
@export var squash_amount: float = 0.12 # scale deviation from base

var _state_timer: float = 0.0
var _is_moving: bool = false
var villager_name: String = ""
var villager_id: int = -1
var _squash_time: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE

## Breeding House (#8): once true, short-circuits the idle/wander state
## machine below in favor of walking straight to _walk_target.
var _housed: bool = false
var _walk_target: Vector2
var _arrival_callback: Callable
const _ARRIVAL_DISTANCE: float = 4.0

@onready var _name_label: Label = $NameLabel
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("villager")
	_enter_idle()
	_name_label.text = villager_name
	_base_sprite_scale = _sprite.scale


## Sends this villager to walk to target_position and disappear on
## arrival (Breeding House, #8) — permanent until this node is freed by
## GameState.start_breeding()'s villager_removed signal.
func walk_to_and_hide(target_position: Vector2, on_arrived: Callable) -> void:
	_housed = true
	_walk_target = target_position
	_arrival_callback = on_arrived


## Identity label (#36) — cosmetic only, no mechanical effect.
func set_villager_name(new_name: String) -> void:
	villager_name = new_name
	if is_inside_tree():
		_name_label.text = villager_name


func _physics_process(delta: float) -> void:
	if _housed:
		_process_housed_walk()
		move_and_slide()
		_update_squash(delta)
		return

	_state_timer -= delta
	if _state_timer <= 0.0:
		if _is_moving:
			_enter_idle()
		else:
			_enter_move()

	move_and_slide()
	_update_squash(delta)


func _process_housed_walk() -> void:
	if global_position.distance_to(_walk_target) <= _ARRIVAL_DISTANCE:
		velocity = Vector2.ZERO
		visible = false
		set_physics_process(false)
		_arrival_callback.call(villager_id)
		return
	_is_moving = true
	velocity = global_position.direction_to(_walk_target) * move_speed


func _update_squash(delta: float) -> void:
	if _is_moving:
		_squash_time += delta * squash_speed
		var wobble: float = sin(_squash_time * TAU)
		_sprite.scale = _base_sprite_scale * Vector2(1.0 - wobble * squash_amount, 1.0 + wobble * squash_amount)
	else:
		_squash_time = 0.0
		_sprite.scale = _sprite.scale.lerp(_base_sprite_scale, 10.0 * delta)


func _enter_idle() -> void:
	_is_moving = false
	velocity = Vector2.ZERO
	_state_timer = randf_range(min_idle_time, max_idle_time)


func _enter_move() -> void:
	_is_moving = true
	velocity = Vector2.from_angle(randf() * TAU) * move_speed
	_state_timer = randf_range(min_move_time, max_move_time)
