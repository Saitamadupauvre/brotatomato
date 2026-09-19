class_name MapMarkerArrow
extends Control
## Small triangle pointing along +X at rotation 0; the parent sets
## rotation to the player's facing angle. Drawn instead of using a
## sprite so the minimap needs no extra art asset.

@export var color: Color = Color(1.0, 0.95, 0.3)


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(size.x, size.y / 2.0),
		Vector2(0.0, 0.0),
		Vector2(0.0, size.y),
	])
	draw_colored_polygon(points, color)
