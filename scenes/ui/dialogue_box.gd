class_name DialogueBox
extends MenuPanel
## Plays a DialogueData sequence, one line at a time, typed out character
## by character. Advances on interact (or instantly fills the line if
## still typing), closes early on cancel/interact-at-last-line. Own
## _input (not MenuPanel's) since interact must advance here, not just
## close.

@export var chars_per_second: float = 40.0

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: Label = %TextLabel
@onready var _type_timer: Timer = Timer.new()

var _lines: Array[DialogueLine] = []
var _index: int = 0
var _full_text: String = ""
var _shown_chars: int = 0


func _ready() -> void:
	super()
	add_to_group("dialogue_ui")
	_type_timer.one_shot = false
	_type_timer.timeout.connect(_on_type_tick)
	add_child(_type_timer)


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


func close() -> void:
	_type_timer.stop()
	super()


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
