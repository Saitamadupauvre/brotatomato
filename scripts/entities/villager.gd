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
var _squash_time: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE

@onready var _name_label: Label = $NameLabel
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_enter_idle()
	_name_label.text = villager_name
	_base_sprite_scale = _sprite.scale


## Identity label (#36) — cosmetic only, no mechanical effect.
func set_villager_name(new_name: String) -> void:
	villager_name = new_name
	if is_inside_tree():
		_name_label.text = villager_name


func _physics_process(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		if _is_moving:
			_enter_idle()
		else:
			_enter_move()

	move_and_slide()
	_update_squash(delta)


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
