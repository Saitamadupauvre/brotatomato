class_name MapIcon
extends Control
## Small hand-drawn marker for a minimap point of interest. No sprite
## asset needed: each kind is a couple of primitive shapes.

@export var kind: MapPoi.Kind = MapPoi.Kind.ENEMY


func _draw() -> void:
	match kind:
		MapPoi.Kind.ENEMY:
			_draw_enemy()
		MapPoi.Kind.CHEST:
			_draw_chest()


## Red diamond with a darker outline, reads as "danger" at a glance.
func _draw_enemy() -> void:
	var half := size / 2.0
	var points := PackedVector2Array([
		Vector2(half.x, 0.0),
		Vector2(size.x, half.y),
		Vector2(half.x, size.y),
		Vector2(0.0, half.y),
	])
	draw_colored_polygon(points, Color(0.85, 0.2, 0.15))
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.35, 0.05, 0.05), 0.15)


## Golden-brown box with a lid line, reads as "loot".
func _draw_chest() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.65, 0.45, 0.2))
	draw_rect(rect, Color(0.3, 0.18, 0.05), false, 0.15)
	draw_line(Vector2(0.0, size.y * 0.4), Vector2(size.x, size.y * 0.4), Color(0.3, 0.18, 0.05), 0.12)
