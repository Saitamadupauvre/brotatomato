class_name HUD
extends Control
## HUD: reads GameState via signals only, never mutates it. Exception:
## the dungeon scene calls setup_minimap() once per run to hand over
## the generated layout and player node, since that's per-run data with
## no natural GameState signal to read it from.

const FOG_REVEAL_RADIUS: int = 7

@onready var tomato_label: Label = %TomatoLabel
@onready var gold_label: Label = %GoldLabel
@onready var _minimap: MinimapDisplay = %Minimap
@onready var _map_overlay: MapOverlay = %MapOverlay

var _layout: DungeonLayout
var _player: CharacterBody2D
var _fog: FogOfWar


func _ready() -> void:
	GameState.tomato_changed.connect(_on_tomato_changed)
	GameState.item_changed.connect(_on_item_changed)
	_on_tomato_changed(GameState.tomatoes)
	_on_item_changed("gold", GameState.get_item_count("gold"))


func _process(_delta: float) -> void:
	if _layout == null or not is_instance_valid(_player):
		return
	var cell := _layout.world_to_cell(_player.position)
	_fog.reveal(cell, FOG_REVEAL_RADIUS)
	var facing: Vector2 = _player.velocity if _player.velocity.length() > 1.0 else Vector2.RIGHT
	_minimap.update_player(_player.position, facing)
	_map_overlay.update_player(_player.position, facing)


## Called once by the dungeon scene after it builds the layout and
## places the player. No-op in Camp, which never calls it.
func setup_minimap(layout: DungeonLayout, player: CharacterBody2D) -> void:
	_layout = layout
	_player = player
	_fog = FogOfWar.new(layout.width, layout.height)
	_minimap.set_layout(layout)
	_minimap.set_fog(_fog)
	_map_overlay.set_layout(layout)
	_map_overlay.set_fog(_fog)
	_minimap.visible = true


func set_points_of_interest(pois: Array[MapPoi]) -> void:
	_minimap.set_points_of_interest(pois)
	_map_overlay.set_points_of_interest(pois)


func _on_tomato_changed(count: int) -> void:
	tomato_label.text = "%d" % count


func _on_item_changed(item_id: String, count: int) -> void:
	if item_id == "gold":
		gold_label.text = "%d" % count
