class_name DungeonMapTexture
extends RefCounted
## Builds a one-pixel-per-cell terrain texture from a DungeonLayout, for
## the minimap and full map view. Neutral greyscale by design (not the
## in-world forest palette) so it reads as a "map", not a shrunk photo
## of the level.

const FLOOR_COLOR := Color(0.78, 0.78, 0.8)
const WALL_COLOR := Color(0.32, 0.32, 0.35)


static func build(layout: DungeonLayout) -> ImageTexture:
	var image := Image.create(layout.width, layout.height, false, Image.FORMAT_RGB8)
	for y in layout.height:
		for x in layout.width:
			image.set_pixel(x, y, FLOOR_COLOR if layout.is_floor(x, y) else WALL_COLOR)
	return ImageTexture.create_from_image(image)
