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
var _plot_id: int = -1
var _sprite: CanvasItem = null
var _plant_sprite: Sprite2D = null
var _time_label: Label = null
var _attention_outline: CanvasItem = null


func is_empty() -> bool:
	return _state == PlotState.EMPTY


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	add_to_group("plot_behavior") # Instant Harvest card active (#7) targets this group
	_sprite = owner_entity.get_node(sprite_path)
	_plant_sprite = owner_entity.get_node(plant_sprite_path)
	_time_label = owner_entity.get_node(time_label_path)
	_attention_outline = OutlineVisual.create(_sprite, Color(1.0, 0.9, 0.2), 6.0, 1.15)
	_plot_id = owner_entity.get_meta("plot_id", -1)
	_restore_progress()
	_update_visuals()


## Plots are freed and reinstanced on every scene change (#91: Camp <->
## Dungeon), so this behavior itself can't remember planting/growth across
## a dungeon trip — GameState.get_plot_progress is what's actually alive.
## grow_end_unix is a real clock timestamp, so growth keeps counting down
## for real while the player's away, not frozen and resumed on return.
func _restore_progress() -> void:
	var progress: Dictionary = GameState.get_plot_progress(_plot_id)
	if progress.is_empty():
		return
	_state = progress["state"] as PlotState
	if _state == PlotState.GROWING:
		_grow_timer = progress["grow_end_unix"] - Time.get_unix_time_from_system()
		if _grow_timer <= 0.0:
			_state = PlotState.RIPE
			_persist_progress()


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
func is_growing() -> bool:
	return _state == PlotState.GROWING


## Instant Harvest card active (#7) — skips straight to RIPE.
func force_ripen() -> void:
	if _state != PlotState.GROWING:
		return
	_state = PlotState.RIPE
	_update_visuals()
	_persist_progress()


func _process(delta: float) -> void:
	if _state == PlotState.GROWING:
		_grow_timer -= delta
		_time_label.text = "%ds" % int(ceil(_grow_timer))
		if _grow_timer <= 0.0:
			_state = PlotState.RIPE
			_update_visuals()
			_persist_progress()


func on_event(event_name: String, _payload: Dictionary = {}) -> void:
	if event_name != "interacted":
		return
	match _state:
		PlotState.EMPTY:
			if GameState.plant_crop():
				AudioManager.play(&"plant_seed")
				_state = PlotState.SEEDED
				_update_visuals()
				_persist_progress()
		PlotState.SEEDED:
			if GameState.remove_item("water", 1):
				AudioManager.play(&"water_plot")
				_state = PlotState.GROWING
				_grow_timer = grow_time / GameState.get_passive_multiplier(CardData.Passive.PLOT_GROWTH_SPEED)
				_update_visuals()
				_persist_progress()
		PlotState.RIPE:
			AudioManager.play(&"harvest")
			GameState.spawn_villager(owner_entity.global_position)
			GameState.add_item("crop", 1)
			_state = PlotState.EMPTY
			_update_visuals()
			_persist_progress()
		PlotState.GROWING:
			pass


func _persist_progress() -> void:
	var grow_end_unix := 0.0
	if _state == PlotState.GROWING:
		grow_end_unix = Time.get_unix_time_from_system() + _grow_timer
	GameState.set_plot_progress(_plot_id, _state, grow_end_unix)


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
