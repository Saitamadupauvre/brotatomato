extends Control
## Shared defeat/win screen: types `message` out letter by letter, then
## reveals a button back to the main menu. Standalone scene (not a
## MenuPanel overlay) — the whole scene IS the screen.

@export_multiline var message: String = ""
@export var chars_per_second: float = 40.0

@onready var _text_label: Label = %TextLabel
@onready var _menu_button: Button = %MenuButton
@onready var _type_timer: Timer = Timer.new()

var _shown_chars: int = 0


func _ready() -> void:
	UITheme.style_button(_menu_button)
	_menu_button.pressed.connect(_on_menu_pressed)
	_menu_button.hide()
	_text_label.text = ""
	_type_timer.one_shot = false
	_type_timer.wait_time = 1.0 / chars_per_second
	_type_timer.timeout.connect(_on_type_tick)
	add_child(_type_timer)
	_type_timer.start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if _shown_chars < message.length():
			_finish_typing()
			get_viewport().set_input_as_handled()


func _on_type_tick() -> void:
	_shown_chars += 1
	_text_label.text = message.substr(0, _shown_chars)
	if _shown_chars >= message.length():
		_finish_typing()


func _finish_typing() -> void:
	_type_timer.stop()
	_shown_chars = message.length()
	_text_label.text = message
	_menu_button.show()


func _on_menu_pressed() -> void:
	SceneRouter.go_to_menu()
