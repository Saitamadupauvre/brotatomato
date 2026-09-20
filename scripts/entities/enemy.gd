class_name Enemy
extends CharacterBody2D
## Thin host — no hardcoded movement/attack. Behaviors dropped under Host
## (see enemy_base.tscn's variants) decide how this enemy moves and
## attacks; this script only owns the shared contract they read/write.

@export var data: EnemyData
@export var squash_speed: float = 5.0 # squash cycles per second while moving
@export var squash_amount: float = 0.05 # scale deviation from base
@export var squash_min_speed: float = 40.0 # only wobble above this velocity, so idle jitter doesn't trigger it

var player: Node2D = null
var movement_locked: bool = false # an attack behavior sets this while it owns velocity

@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $Hurtbox
@onready var _host: BehaviorHost = $Host
@onready var _sprite: Sprite2D = $Sprite

var _squash_time: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	add_to_group("enemy") # Damage Burst card active (#7) targets this group
	if _sprite.material:
		_sprite.material = _sprite.material.duplicate() # else every enemy shares one ShaderMaterial and flashes fight each other
	_base_sprite_scale = _sprite.scale
	health.configure(data.max_hp)
	health.died.connect(_on_died)
	_hurtbox.damage_taken.connect(health.take_damage)
	_hurtbox.damage_taken.connect(_on_hurt)
	player = get_tree().get_first_node_in_group("player")


func _on_hurt(_amount: int) -> void:
	HitFlash.flash(_sprite)


func _physics_process(delta: float) -> void:
	_host.broadcast("physics_tick", {"delta": delta})
	move_and_slide()
	_update_squash(delta)


## Same wobble as Villager's idle/wander squash (villager.gd) — stretches
## along the move axis instead of scaling uniformly, so it reads as a
## bounce rather than a pulse.
func _update_squash(delta: float) -> void:
	if velocity.length() > squash_min_speed:
		_squash_time += delta * squash_speed
		var wobble: float = sin(_squash_time * TAU)
		_sprite.scale = _base_sprite_scale * Vector2(1.0 - wobble * squash_amount, 1.0 + wobble * squash_amount)
	else:
		_squash_time = 0.0
		_sprite.scale = _sprite.scale.lerp(_base_sprite_scale, 10.0 * delta)


func _on_died() -> void:
	queue_free()
