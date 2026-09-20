class_name SpriteScale
extends RefCounted
## Item/prop art comes from wildly different source resolutions (a 480x480
## coin next to a 3840x2176 gun), so a single hand-tuned Sprite2D.scale
## per scene breaks the moment a different texture is dropped in. fit()
## normalizes any Sprite2D to a target on-screen size regardless of its
## texture's native resolution — the fix for "the gun/card render huge,
## the bullet renders tiny" once the same node is reused for several items.

static func fit(sprite: Sprite2D, target_size: float) -> void:
	if sprite.texture == null:
		return
	var tex_size := sprite.texture.get_size()
	var largest: float = max(tex_size.x, tex_size.y)
	if largest <= 0.0:
		return
	var factor := target_size / largest
	sprite.scale = Vector2(factor, factor)
