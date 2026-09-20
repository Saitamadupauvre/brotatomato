class_name Enemy
extends CharacterBody2D
## Thin host — no hardcoded movement/attack. Behaviors dropped under Host
## (see enemy_base.tscn's variants) decide how this enemy moves and
## attacks; this script only owns the shared contract they read/write.

@export var data: EnemyData

var player: Node2D = null
var movement_locked: bool = false # an attack behavior sets this while it owns velocity

@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $Hurtbox
@onready var _host: BehaviorHost = $Host


func _ready() -> void:
	add_to_group("enemy") # Damage Burst card active (#7) targets this group
	health.configure(data.max_hp)
	health.died.connect(queue_free)
	_hurtbox.damage_taken.connect(health.take_damage)
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_host.broadcast("physics_tick", {"delta": delta})
	move_and_slide()
