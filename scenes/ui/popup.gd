class_name Popup
extends MenuPanel
## Generic dismissible message popup. Shows an arbitrary text string over
## whatever scene it's dropped into, auto-dismisses after a delay, and
## dismisses early on any key/click. No gameplay-specific logic — callers
## reach it via the "popup_ui" group, same convention as DialogueBox.

@export var default_duration: float = 2.5

@onready var _text_label: Label = %TextLabel
@onready var _dismiss_timer: Timer = Timer.new()


func _ready() -> void:
	super()
	add_to_group("popup_ui")
	_dismiss_timer.one_shot = true
	_dismiss_timer.timeout.connect(close)
	add_child(_dismiss_timer)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			close()
			get_viewport().set_input_as_handled()


func show_message(text: String, duration: float = -1.0) -> void:
	_text_label.text = text
	_dismiss_timer.stop()
	_dismiss_timer.wait_time = duration if duration > 0.0 else default_duration
	_dismiss_timer.start()
	open()


func close() -> void:
	_dismiss_timer.stop()
	super()
