class_name ShadowCaster
extends Node2D
## Ground shadow blob for an entity. True cross-entity shadow blending
## (overlaps not stacking darker) needs a CanvasGroup, which Godot does
## not support on the GL Compatibility renderer this project targets —
## so this is a plain fixed-alpha blob local to its own entity instead.

@export var radius_x: float = 12.0
@export var radius_y: float = 5.0
@export var offset: Vector2 = Vector2(0, 12)
@export var shadow_alpha: float = 0.35
@export var offset_factor: float = 0.85 # fraction of sprite half-height to drop the shadow — lower pulls it up under the entity


func _ready() -> void:
	var extent := _find_sprite_extent(get_parent())
	var rx := radius_x
	var ry := radius_y
	var off := offset
	if extent > 0.0: # sprite is bigger than the hand-set fallback size — scale shadow to actually poke out from under it
		rx = extent * 0.55
		ry = extent * 0.22
		off = Vector2(0, extent * offset_factor)
	var blob := Polygon2D.new()
	blob.color = Color(0.0, 0.0, 0.0, shadow_alpha)
	blob.polygon = _ellipse_points(rx, ry)
	blob.position = off
	add_child(blob)


func _find_sprite_extent(node: Node) -> float:
	var best := 0.0
	if node is Sprite2D and node.texture:
		var s: Sprite2D = node
		best = max(best, s.texture.get_size().y * absf(s.global_scale.y) * 0.5)
	for child in node.get_children():
		if child != self:
			best = max(best, _find_sprite_extent(child))
	return best


static func _ellipse_points(rx: float, ry: float, segments: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		pts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts
