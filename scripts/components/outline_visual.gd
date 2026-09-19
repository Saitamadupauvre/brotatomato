class_name OutlineVisual
## Shared duplicate-and-tint outline builder. Duplicates a sprite, tints it
## solid, enlarges it slightly, draws it behind the original. Works on
## both Control (ColorRect) and Node2D (Sprite2D) sprites. Used by both
## the proximity-based OutlineBehavior and PlotBehavior's state-driven
## attention outline — one implementation, two callers.

static func create(sprite: CanvasItem, color: Color, margin: float = 6.0, scale_factor: float = 1.2) -> CanvasItem:
	var outline: CanvasItem = sprite.duplicate()
	outline.material = null
	outline.modulate = color
	outline.visible = false
	if outline is Control:
		var c := outline as Control
		c.offset_left -= margin
		c.offset_top -= margin
		c.offset_right += margin
		c.offset_bottom += margin
	else:
		outline.scale *= scale_factor
	var parent := sprite.get_parent()
	# Callers build these during BehaviorHost._ready(), while the scene
	# tree is still busy setting up children — add_child must be deferred.
	parent.add_child.call_deferred(outline)
	parent.call_deferred("move_child", outline, sprite.get_index())
	return outline
