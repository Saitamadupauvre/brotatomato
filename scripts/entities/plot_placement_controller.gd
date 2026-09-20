class_name PlotPlacementController
extends Node2D
## Free-form grid placement (and relocation) for plots. Not a Behavior: no
## proximity trigger, no single owner entity — an always-present input-mode
## toggle, closer in shape to MenuPanel than to an interactable.

enum Mode { IDLE, PLACING, MOVING }

const CELL_SIZE: float = 64.0
## Gold cost to place a plot — no longer a materials/crafting cost (cut as
## out of scope), just a Shop-style gold spend like the Breeding House.
const GOLD_COST: int = 30
const PLOT_HALF_SIZE: float = 28.0
const CAMP_MIN: Vector2 = Vector2(32 + PLOT_HALF_SIZE, 32 + PLOT_HALF_SIZE)
const CAMP_MAX: Vector2 = Vector2(944 - PLOT_HALF_SIZE, 624 - PLOT_HALF_SIZE)
const MIN_PLOT_SPACING: float = CELL_SIZE * 0.9
## How close the mouse must be to an existing plot to pick it up with R.
const PICK_RADIUS: float = 40.0
const FEEDBACK_DURATION: float = 1.5
const PLOT_BEHAVIOR_PATH: NodePath = ^"Interactable/Host/PlotBehavior"
## Placement (#91) has no Interactable to hang a TutorialTriggerBehavior
## off of — it's a global input-mode toggle, not proximity-based like every
## other tutorial — so it's triggered directly here, checked every frame
## against the player's own position instead of an Area2D signal, same
## exception as Main's camp-intro dialogue.
const PLOT_PLACEMENT_DIALOGUE: DialogueData = preload("res://resources/dialogue/plot_placement.tres")

@export var plots_container_path: NodePath = ^"../Plots"
@onready var _preview: ColorRect = $Preview
@onready var _feedback_label: Label = $FeedbackLayer/FeedbackLabel

var _mode: Mode = Mode.IDLE
var _preview_position: Vector2 = Vector2.ZERO
var _moving_plot: Node2D = null
var _moving_plot_origin: Vector2 = Vector2.ZERO
var _feedback_timer: SceneTreeTimer = null


func _input(event: InputEvent) -> void:
	match _mode:
		Mode.IDLE:
			if event.is_action_pressed("place_plot"):
				start_placing()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("move_plot"):
				_try_start_moving()
				get_viewport().set_input_as_handled()
		Mode.PLACING:
			if event.is_action_pressed("ui_cancel"):
				_exit_mode()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
				_try_confirm_placing()
				get_viewport().set_input_as_handled()
		Mode.MOVING:
			if event.is_action_pressed("ui_cancel"):
				_cancel_moving()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
				_try_confirm_moving()
				get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_check_placement_tutorial_proximity()
	if _mode == Mode.IDLE:
		return
	_preview_position = (get_global_mouse_position() / CELL_SIZE).round() * CELL_SIZE
	_preview.global_position = _preview_position - Vector2(PLOT_HALF_SIZE, PLOT_HALF_SIZE)
	var valid := _is_valid_position(_preview_position)
	_preview.color = Color(0.3, 0.9, 0.3, 0.6) if valid else Color(0.9, 0.3, 0.3, 0.6)


## Fires the G-to-place hint the first time the player stands close to an
## open, placeable spot — not the first time they happen to press G — so
## the player learns the key exists before they'd need to already know it.
func _check_placement_tutorial_proximity() -> void:
	if TutorialManager.has_seen("plot_placement"):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _is_valid_position((player.global_position / CELL_SIZE).round() * CELL_SIZE):
		TutorialManager.trigger("plot_placement", PLOT_PLACEMENT_DIALOGUE)


func _try_start_placing() -> void:
## Public: also called by the Shop's Plot card, not just the place_plot key.
func start_placing() -> void:
	if GameState.get_item_count("gold") < GOLD_COST:
		_show_feedback("Not enough gold (need %d, have %d)" % [GOLD_COST, GameState.get_item_count("gold")])
		return
	_mode = Mode.PLACING
	_preview.visible = true


func _try_confirm_placing() -> void:
	if not _is_valid_position(_preview_position):
		_show_feedback("Can't place here")
		return
	if not GameState.remove_item("gold", GOLD_COST):
		_show_feedback("Not enough gold")
		return
	GameState.add_plot(_preview_position)
	_exit_mode()


func _try_start_moving() -> void:
	var candidate: Node2D = _find_nearby_empty_plot()
	if candidate == null:
		_show_feedback("No empty plot nearby")
		return
	_moving_plot = candidate
	_moving_plot_origin = candidate.global_position
	candidate.visible = false
	_mode = Mode.MOVING
	_preview.visible = true


func _try_confirm_moving() -> void:
	if not _is_valid_position(_preview_position):
		_show_feedback("Can't place here")
		return
	_moving_plot.global_position = _preview_position
	_moving_plot.visible = true
	GameState.move_plot(_moving_plot.get_meta("plot_id"), _preview_position)
	_moving_plot = null
	_exit_mode()


func _cancel_moving() -> void:
	_moving_plot.global_position = _moving_plot_origin
	_moving_plot.visible = true
	_moving_plot = null
	_exit_mode()


func _exit_mode() -> void:
	_mode = Mode.IDLE
	_preview.visible = false


func _find_nearby_empty_plot() -> Node2D:
	var mouse_position: Vector2 = get_global_mouse_position()
	var closest: Node2D = null
	var closest_distance: float = PICK_RADIUS
	for plot in get_node(plots_container_path).get_children():
		if not plot is Node2D:
			continue
		var behavior: PlotBehavior = plot.get_node_or_null(PLOT_BEHAVIOR_PATH) as PlotBehavior
		if behavior == null or not behavior.is_empty():
			continue
		var distance: float = plot.global_position.distance_to(mouse_position)
		if distance < closest_distance:
			closest = plot
			closest_distance = distance
	return closest


func _is_valid_position(pos: Vector2) -> bool:
	if pos.x < CAMP_MIN.x or pos.x > CAMP_MAX.x or pos.y < CAMP_MIN.y or pos.y > CAMP_MAX.y:
		return false
	for plot in get_node(plots_container_path).get_children():
		if plot == _moving_plot:
			continue
		if plot is Node2D and plot.global_position.distance_to(pos) < MIN_PLOT_SPACING:
			return false
	return true


func _show_feedback(text: String) -> void:
	_feedback_label.text = text
	_feedback_label.visible = true
	_feedback_timer = get_tree().create_timer(FEEDBACK_DURATION)
	_feedback_timer.timeout.connect(func() -> void: _feedback_label.visible = false)
