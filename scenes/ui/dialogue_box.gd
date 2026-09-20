class_name DialogueBox
extends MenuPanel
## Plays a DialogueData sequence, one line at a time, typed out character
## by character. Advances on interact (or instantly fills the line if
## still typing), closes early on cancel/interact-at-last-line. Own
## _input (not MenuPanel's) since interact must advance here, not just
## close.
##
## Freezes gameplay while open (#91) — process_mode is ALWAYS (set on the
## scene root) so this node keeps running under pause. Scoped to this box
## alone, not lifted into MenuPanel, so Shop/Inventory stay real-time.

@export var chars_per_second: float = 40.0
@export var portrait_bounce_height: float = 10.0
@export var portrait_bounce_speed: float = 4.0

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: Label = %TextLabel
@onready var _portrait: Control = %Portrait
@onready var _type_timer: Timer = Timer.new()

var _lines: Array[DialogueLine] = []
var _index: int = 0
var _full_text: String = ""
var _shown_chars: int = 0
var _portrait_base_y: float = 0.0
var _bounce_tween: Tween = null


func _ready() -> void:
	super()
	add_to_group("dialogue_ui")
	_type_timer.one_shot = false
	_type_timer.timeout.connect(_on_type_tick)
	add_child(_type_timer)
	_portrait_base_y = _portrait.position.y


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if _is_typing():
			_finish_typing()
		else:
			_advance()
		get_viewport().set_input_as_handled()


func play(dialogue: DialogueData) -> void:
	if dialogue == null or dialogue.lines.is_empty():
		return
	_lines = dialogue.lines
	_index = 0
	_show_current()
	open()


func open() -> void:
	super()
	get_tree().paused = true
	_start_bounce()


func close() -> void:
	_type_timer.stop()
	_stop_bounce()
	get_tree().paused = false
	super()


func _start_bounce() -> void:
	_stop_bounce()
	_bounce_tween = create_tween().set_loops()
	_bounce_tween.tween_property(_portrait, "position:y", _portrait_base_y - portrait_bounce_height, portrait_bounce_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bounce_tween.tween_property(_portrait, "position:y", _portrait_base_y, portrait_bounce_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_bounce() -> void:
	if _bounce_tween:
		_bounce_tween.kill()
		_bounce_tween = null
	_portrait.position.y = _portrait_base_y


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		_show_current()


func _show_current() -> void:
	var line: DialogueLine = _lines[_index]
	_speaker_label.text = line.speaker
	_full_text = line.text
	_shown_chars = 0
	_text_label.text = ""
	_type_timer.wait_time = 1.0 / chars_per_second
	_type_timer.start()


func _is_typing() -> bool:
	return _shown_chars < _full_text.length()


func _finish_typing() -> void:
	_type_timer.stop()
	_shown_chars = _full_text.length()
	_text_label.text = _full_text


func _on_type_tick() -> void:
	_shown_chars += 1
	_text_label.text = _full_text.substr(0, _shown_chars)
	if not _is_typing():
		_type_timer.stop()
