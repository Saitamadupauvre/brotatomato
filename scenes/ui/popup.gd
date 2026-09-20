class_name PopupModal
extends Control
## Stack of short-lived toast messages, top-left corner. Each
## show_message() call queues its own entry with its own dismiss timer —
## entries are independent, not one shared message — and the oldest is
## dropped once MAX_STACK is exceeded so a burst of hits never overflows
## the corner. No gameplay-specific logic — callers reach it via direct
## node reference (see dungeon.gd).

const MAX_STACK: int = 4

@export var default_duration: float = 2.5

@onready var _stack: VBoxContainer = %Stack


func show_message(text: String, duration: float = -1.0) -> void:
	var entry := _make_entry(text)
	_stack.add_child(entry)
	if _stack.get_child_count() > MAX_STACK:
		_stack.get_child(0).queue_free()

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration if duration > 0.0 else default_duration
	entry.add_child(timer)
	timer.timeout.connect(entry.queue_free)
	timer.start()


func _make_entry(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _entry_style())

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel


func _entry_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.85, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 8.0
	return style
