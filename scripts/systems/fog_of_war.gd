class_name FogOfWar
extends RefCounted
## Per-run exploration state for one dungeon layout: which cells the
## player has seen. Reveals are circular around the player each frame;
## the black overlay image is mutated in place and only re-uploaded to
## the GPU when something actually changed.

var width: int
var height: int
var revealed: PackedByteArray
var _image: Image
var _texture: ImageTexture
var _dirty: bool = true


func _init(map_width: int, map_height: int) -> void:
	width = map_width
	height = map_height
	revealed = PackedByteArray()
	revealed.resize(width * height)
	_image = Image.create(width, height, false, Image.FORMAT_LA8)
	_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_texture = ImageTexture.create_from_image(_image)


## Reveals every cell within radius of center. Returns true if any cell
## was newly revealed (caller can skip work otherwise).
func reveal(center: Vector2i, radius: int) -> bool:
	var changed := false
	var radius_sq := radius * radius
	var min_y: int = maxi(center.y - radius, 0)
	var max_y: int = mini(center.y + radius, height - 1)
	var min_x: int = maxi(center.x - radius, 0)
	var max_x: int = mini(center.x + radius, width - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy > radius_sq:
				continue
			var idx := y * width + x
			if revealed[idx] == 0:
				revealed[idx] = 1
				_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				changed = true
	if changed:
		_dirty = true
	return changed


func is_revealed(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	return revealed[y * width + x] == 1


## Black-with-alpha overlay: opaque where unseen, transparent where
## revealed. Lazily re-uploaded only when reveal() actually changed it.
func get_texture() -> ImageTexture:
	if _dirty:
		_texture.update(_image)
		_dirty = false
	return _texture
