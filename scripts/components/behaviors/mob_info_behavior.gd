class_name MobInfoBehavior
extends EnemyBehavior
## Shows current/max HP above the enemy's head as a tomato icon + count.
## Universal — added once in enemy_base.tscn, every variant gets it free.

const TOMATO_ICON: Texture2D = preload("res://icon.svg")

@export var offset: Vector2 = Vector2(0, -32)

var _label: Label = null


func _setup(p_owner: Node2D, p_host: BehaviorHost) -> void:
	super(p_owner, p_host)
	var row := HBoxContainer.new()
	row.position = offset

	var icon := TextureRect.new()
	icon.texture = TOMATO_ICON
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.modulate = Color(0.9, 0.2, 0.2)
	row.add_child(icon)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	row.add_child(_label)

	enemy.add_child.call_deferred(row)
	
	var health_component: HealthComponent = enemy.get_node("HealthComponent")
	health_component.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, max_hp: int) -> void:
	_label.text = "%d/%d" % [current, max_hp]
