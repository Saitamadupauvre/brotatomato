class_name MinimapDisplay
extends Control
## Renders one DungeonLayout + FogOfWar as either a small player-centered
## window (MINI, top-right HUD corner) or the whole map fit to the
## available space (FULL, the M-key overlay). Both modes share the same
## child nodes, composited through a SubViewport so minimap_mask.gdshader
## can clip MINI to a circle (FULL stays rectangular); only MapRoot's
## scale/position math differs between the two.

enum Mode { MINI, FULL }

@export var mode: Mode = Mode.MINI
## Pixels per dungeon cell in MINI mode. FULL computes its own scale to
## fit whatever space it's given.
@export var mini_cell_px: float = 6.0

const ICON_SIZE: Dictionary = {
	MapPoi.Kind.ENEMY: Vector2(1.5, 1.5),
	MapPoi.Kind.CHEST: Vector2(1.3, 1.3),
}

@onready var _background: Panel = %Background
@onready var _frame: SubViewportContainer = %Frame
@onready var _viewport: SubViewport = %SubViewport
@onready var _map_root: Control = %MapRoot
@onready var _base: TextureRect = %Base
@onready var _fog: TextureRect = %Fog
@onready var _player_marker: MapMarkerArrow = %PlayerMarker
@onready var _exit_marker: Control = %ExitMarker

var _layout: DungeonLayout
var _fog_of_war: FogOfWar
var _pois: Array[MapPoi] = []
var _poi_icons: Array[MapIcon] = []


func _ready() -> void:
	# ShaderMaterial sub_resource is shared across every instance of this
	# scene unless duplicated: MINI and FULL would otherwise fight over
	# the same "circular" flag.
	var mask_material: ShaderMaterial = (_frame.material as ShaderMaterial).duplicate()
	_frame.material = mask_material
	mask_material.set_shader_parameter("circular", mode == Mode.MINI)
	if mode == Mode.MINI:
		_map_root.scale = Vector2(mini_cell_px, mini_cell_px)
		# StyleBoxFlat clamps radius to half the control's own size, so a
		# huge value always yields a perfect circle regardless of pixel size.
		var circle_style: StyleBoxFlat = (_background.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		circle_style.set_corner_radius_all(999)
		_background.add_theme_stylebox_override("panel", circle_style)


func set_layout(layout: DungeonLayout) -> void:
	_layout = layout
	_base.texture = DungeonMapTexture.build(layout)
	_base.size = Vector2(layout.width, layout.height)
	_exit_marker.position = Vector2(layout.exit_cell) + Vector2(0.5, 0.5) - _exit_marker.size / 2.0
	_exit_marker.visible = false
	if mode == Mode.FULL:
		_fit_full()


func set_fog(fog: FogOfWar) -> void:
	_fog_of_war = fog
	_fog.texture = fog.get_texture()
	_fog.size = Vector2(_layout.width, _layout.height)


## Rebuilds the icon set. Called once per run; icons then just track
## their node's position (or hide themselves when it's freed).
func set_points_of_interest(pois: Array[MapPoi]) -> void:
	for icon in _poi_icons:
		icon.queue_free()
	_poi_icons.clear()
	_pois = pois
	for poi in pois:
		var icon := MapIcon.new()
		icon.kind = poi.kind
		var icon_size: Vector2 = ICON_SIZE[poi.kind]
		icon.size = icon_size
		icon.pivot_offset = icon_size / 2.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_root.add_child(icon)
		_map_root.move_child(icon, _fog.get_index() + 1)
		_poi_icons.append(icon)


func update_player(world_pos: Vector2, facing: Vector2) -> void:
	if _layout == null:
		return
	var cell := world_pos / _layout.cell_size
	_player_marker.position = cell - _player_marker.size / 2.0
	if facing != Vector2.ZERO:
		_player_marker.rotation = facing.angle()
	_fog.texture = _fog_of_war.get_texture()
	_exit_marker.visible = _fog_of_war.is_revealed(_layout.exit_cell.x, _layout.exit_cell.y)
	_update_poi_icons()
	if mode == Mode.MINI:
		_map_root.position = Vector2(_viewport.size) / 2.0 - cell * mini_cell_px
	else:
		_fit_full()


func _update_poi_icons() -> void:
	for i in _pois.size():
		var poi: MapPoi = _pois[i]
		var icon: MapIcon = _poi_icons[i]
		if not is_instance_valid(poi.node):
			icon.visible = false
			continue
		var poi_cell := poi.node.position / _layout.cell_size
		icon.position = poi_cell - icon.size / 2.0
		icon.visible = _fog_of_war.is_revealed(int(poi_cell.x), int(poi_cell.y))


## FULL mode's frame can resize with the window, so refit each update
## instead of caching a stale scale from the frame it opened in.
func _fit_full() -> void:
	var viewport_size := Vector2(_viewport.size)
	if _layout == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var px: float = minf(viewport_size.x / _layout.width, viewport_size.y / _layout.height)
	_map_root.scale = Vector2(px, px)
	_map_root.position = (viewport_size - Vector2(_layout.width, _layout.height) * px) / 2.0
