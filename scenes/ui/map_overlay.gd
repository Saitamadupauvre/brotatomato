class_name MapOverlay
extends MenuPanel
## Full-map view, opened with M. Same layout/fog data as the HUD
## minimap, just rendered fit-to-screen instead of player-centered.

@onready var _display: MinimapDisplay = %MapDisplay


func _input(event: InputEvent) -> void:
	super(event)
	if event.is_action_pressed("toggle_map"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func set_layout(layout: DungeonLayout) -> void:
	_display.set_layout(layout)


func set_fog(fog: FogOfWar) -> void:
	_display.set_fog(fog)


func set_points_of_interest(pois: Array[MapPoi]) -> void:
	_display.set_points_of_interest(pois)


func update_player(world_pos: Vector2, facing: Vector2) -> void:
	if visible:
		_display.update_player(world_pos, facing)
