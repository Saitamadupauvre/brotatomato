class_name HealthComponent
extends Node

signal health_changed(current: int, max: int)
signal died

@export var max_hp: int = 3

var current_hp: int


func _ready() -> void:
	current_hp = max_hp


## Re-syncs current_hp too — needed because a caller sets max_hp from
## data in its own _ready(), which runs AFTER this component's _ready().
func configure(new_max_hp: int) -> void:
	max_hp = new_max_hp
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)


func take_damage(amount: int) -> void:
	AudioManager.play(&"hit_impact")
	current_hp = max(current_hp - amount, 0)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit()
