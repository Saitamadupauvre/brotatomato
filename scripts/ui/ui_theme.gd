class_name UITheme
extends RefCounted
## Shared parchment palette + StyleBoxFlat factories, so every menu built
## at runtime (shop/inventory/chest/card-shop cards, buttons, slots) looks
## like one consistent game UI instead of each script picking its own
## ad-hoc colors.

const PANEL_FILL := Color(0.9, 0.83, 0.62, 0.96)
const PANEL_BORDER := Color(0.55, 0.4, 0.2, 1)
const SLOT_FILL := Color(0.82, 0.73, 0.5, 1)
const SLOT_EMPTY_FILL := Color(0.78, 0.68, 0.45, 0.6)
const SLOT_BORDER := Color(0.55, 0.4, 0.2, 0.8)
const ACCENT_GOLD := Color(0.95, 0.8, 0.3, 1)
const TEXT_DARK := Color(0.35, 0.22, 0.05, 1)
const TEXT_HINT := Color(0.5, 0.38, 0.18, 1)
const BUTTON_FILL := Color(0.55, 0.4, 0.2, 1)
const BUTTON_FILL_HOVER := Color(0.65, 0.48, 0.24, 1)
const BUTTON_FILL_PRESSED := Color(0.45, 0.32, 0.15, 1)
const BUTTON_TEXT := Color(0.96, 0.9, 0.76, 1)


static func panel_style(radius: int = 10, border: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.set_border_width_all(border)
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(radius)
	return style


static func slot_style(filled: bool, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_FILL if filled else SLOT_EMPTY_FILL
	style.set_border_width_all(2)
	style.border_color = SLOT_BORDER
	style.set_corner_radius_all(radius)
	return style


static func highlight_style(radius: int = 8) -> StyleBoxFlat:
	var style := slot_style(true, radius)
	style.set_border_width_all(3)
	style.border_color = ACCENT_GOLD
	return style


static func button_style(fill: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(2)
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


## Applies the parchment look to a plain Button (normal/hover/pressed +
## font color), for buttons built in code or dropped into a .tscn without
## a project-wide theme.
static func style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(BUTTON_FILL))
	button.add_theme_stylebox_override("hover", button_style(BUTTON_FILL_HOVER))
	button.add_theme_stylebox_override("pressed", button_style(BUTTON_FILL_PRESSED))
	button.add_theme_color_override("font_color", BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", BUTTON_TEXT)
