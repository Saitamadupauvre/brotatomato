class_name BreedingHousePlacementController
extends Node2D
## Grid placement for the Breeding House (#87), a one-shot singleton —
## reuses PlotPlacementController's grid-cursor pattern, but no MOVING
## mode (the house never relocates once built).

enum Mode { IDLE, PLACING }

const CELL_SIZE: float = 64.0
const HOUSE_HALF_SIZE: float = 32.0
const CAMP_MIN: Vector2 = Vector2(32 + HOUSE_HALF_SIZE, 32 + HOUSE_HALF_SIZE)
const CAMP_MAX: Vector2 = Vector2(944 - HOUSE_HALF_SIZE, 624 - HOUSE_HALF_SIZE)
const FEEDBACK_DURATION: float = 1.5

@export var obstacles_container_path: NodePath = ^".."

@onready var _preview: ColorRect = $Preview
@onready var _feedback_label: Label = $FeedbackLayer/FeedbackLabel

var _mode: Mode = Mode.IDLE
var _preview_position: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if GameState.breeding_house_placed:
		return
	match _mode:
		Mode.IDLE:
			if event.is_action_pressed("place_breeding_house"):
				_try_start_placing()
				get_viewport().set_input_as_handled()
		Mode.PLACING:
			if event.is_action_pressed("ui_cancel"):
				_exit_mode()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
				_try_confirm_placing()
				get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _mode != Mode.PLACING:
		return
	_preview_position = (get_global_mouse_position() / CELL_SIZE).round() * CELL_SIZE
	_preview.global_position = _preview_position - Vector2(HOUSE_HALF_SIZE, HOUSE_HALF_SIZE)
	_preview.color = Color(0.3, 0.9, 0.3, 0.6) if _is_valid_position(_preview_position) else Color(0.9, 0.3, 0.3, 0.6)


func _try_start_placing() -> void:
	if not GameState.can_create_breeding_house():
		_show_feedback("Not enough gold (need %d, have %d)" % [GameState.BREEDING_HOUSE_GOLD_COST, GameState.get_item_count("gold")])
		return
	_mode = Mode.PLACING
	_preview.visible = true


func _try_confirm_placing() -> void:
	if not _is_valid_position(_preview_position):
		_show_feedback("Can't place here")
		return
	if not GameState.create_breeding_house(_preview_position):
		_show_feedback("Not enough gold")
		return
	_exit_mode()


func _exit_mode() -> void:
	_mode = Mode.IDLE
	_preview.visible = false


func _is_valid_position(pos: Vector2) -> bool:
	if pos.x < CAMP_MIN.x or pos.x > CAMP_MAX.x or pos.y < CAMP_MIN.y or pos.y > CAMP_MAX.y:
		return false
	for obstacle in get_node(obstacles_container_path).get_children():
		if obstacle == self or not obstacle is Node2D:
			continue
		if obstacle.global_position.distance_to(pos) < CELL_SIZE:
			return false
	return true


func _show_feedback(text: String) -> void:
	_feedback_label.text = text
	_feedback_label.visible = true
	get_tree().create_timer(FEEDBACK_DURATION).timeout.connect(func() -> void: _feedback_label.visible = false)
