class_name PlotBehavior
extends Behavior
## Owns a plot's full lifecycle: planting, watering, growth timer, harvest.
## Reacts only to the "interacted" event the Interactable already
## broadcasts — no new trigger plumbing needed.

enum PlotState { EMPTY, SEEDED, GROWING, RIPE }

@export var sprite_path: NodePath
@export var plant_sprite_path: NodePath
@export var time_label_path: NodePath
@export var grow_time: float = 10.0 # TEMP: was 150.0 (GDD 2-3min) — shortened for testing
@export var dirt_dry_tint: Color = Color(1.0, 1.0, 1.0)
@export var dirt_wet_tint: Color = Color(0.45, 0.4, 0.55) # darker, cooler = visibly watered
@export var plant_growing_texture: Texture2D
@export var plant_ripe_texture: Texture2D

var _state: PlotState = PlotState.EMPTY
var _grow_timer: float = 0.0
var _sprite: CanvasItem = null
var _plant_sprite: Sprite2D = null
var _time_label: Label = null
var _attention_outline: CanvasItem = null


func is_empty() -> bool:
	return _state == PlotState.EMPTY


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	_sprite = owner_entity.get_node(sprite_path)
	_plant_sprite = owner_entity.get_node(plant_sprite_path)
	_time_label = owner_entity.get_node(time_label_path)
	_attention_outline = OutlineVisual.create(_sprite, Color(1.0, 0.9, 0.2), 6.0, 1.15)
	_update_visuals()


## Item id the next interaction on this plot consumes, or "" if none
## (GROWING/RIPE need nothing carried). HUD (#49) reads this on the
## closest in-range plot to show only the relevant resource.
func needed_item() -> String:
	match _state:
		PlotState.EMPTY:
			return "crop"
		PlotState.SEEDED:
			return "water"
		_:
			return ""


func _process(delta: float) -> void:
	if _state == PlotState.GROWING:
		_grow_timer -= delta
		_time_label.text = "%ds" % int(ceil(_grow_timer))
		if _grow_timer <= 0.0:
			_state = PlotState.RIPE
			_update_visuals()


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name != "interacted":
		return
	match _state:
		PlotState.EMPTY:
			if GameState.plant_crop():
				_state = PlotState.SEEDED
				_update_visuals()
		PlotState.SEEDED:
			if GameState.remove_item("water", 1):
				_state = PlotState.GROWING
				_grow_timer = grow_time
				_update_visuals()
		PlotState.RIPE:
			GameState.spawn_villager(owner_entity.global_position)
			GameState.add_item("crop", 1)
			_state = PlotState.EMPTY
			_update_visuals()
		PlotState.GROWING:
			pass


func _update_visuals() -> void:
	match _state:
		PlotState.EMPTY:
			_sprite.modulate = dirt_dry_tint
			_plant_sprite.visible = false
		PlotState.SEEDED:
			_sprite.modulate = dirt_dry_tint
			_plant_sprite.texture = plant_growing_texture
			_plant_sprite.visible = true
		PlotState.GROWING:
			_sprite.modulate = dirt_wet_tint
			_plant_sprite.texture = plant_growing_texture
			_plant_sprite.visible = true
		PlotState.RIPE:
			_sprite.modulate = dirt_wet_tint
			_plant_sprite.texture = plant_ripe_texture
			_plant_sprite.visible = true
	_time_label.visible = _state == PlotState.GROWING
	_attention_outline.visible = _state == PlotState.RIPE
