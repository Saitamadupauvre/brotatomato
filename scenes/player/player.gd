extends CharacterBody2D

@export var speed: float = 250.0
@export var acceleration: float = 1500.0
@export var deceleration: float = 1000.0
@export var dash_deceleration: float = 3500.0
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.6
@export var attack_damage: int = 1
@export var attack_duration: float = 0.15
@export var attack_cooldown: float = 0.3

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/dungeon/projectile.tscn")
const ENEMY_HURTBOX_MASK: int = 8

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _last_move_direction: Vector2 = Vector2.DOWN
var _attack_cooldown_timer: float = 0.0

var equipped_weapon: WeaponData = null
var _armor_reduction: int = 0

@onready var _hurtbox: HurtboxComponent = $Hurtbox
@onready var _attack_hitbox: HitboxComponent = $AttackHitbox
@onready var _attack_debug_visual: CanvasItem = $AttackHitbox/DebugVisual


func _ready() -> void:
	add_to_group("player")
	_hurtbox.damage_taken.connect(_on_damage_taken)
	_attack_hitbox.damage = attack_damage
	_attack_hitbox.monitoring = false
	GameState.equipment_changed.connect(_on_equipment_changed)


func _on_equipment_changed(slot: EquipmentData.EquipSlot, _item_id: String) -> void:
	if slot == EquipmentData.EquipSlot.WEAPON:
		equipped_weapon = GameState.get_equipped(slot) as WeaponData
	else:
		_recompute_armor_reduction()


func _recompute_armor_reduction() -> void:
	_armor_reduction = 0
	for armor_slot in EquipmentData.ARMOR_SLOTS:
		var armor := GameState.get_equipped(armor_slot) as ArmorData
		if armor:
			_armor_reduction += armor.damage_reduction


func _on_damage_taken(amount: int) -> void:
	GameState.lose_tomato(max(amount - _armor_reduction, 0))


func _physics_process(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if _is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack()

	move_and_slide()


func _start_attack() -> void:
	var cooldown: float = equipped_weapon.attack_cooldown if equipped_weapon else attack_cooldown
	_attack_cooldown_timer = cooldown

	if equipped_weapon and equipped_weapon.attack_type == WeaponData.AttackType.RANGED:
		_fire_projectile()
	else:
		_swing_melee()


func _fire_projectile() -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.damage = equipped_weapon.damage
	projectile.target_mask = ENEMY_HURTBOX_MASK
	get_parent().add_child(projectile)
	projectile.position = position
	projectile.rotation = _last_move_direction.angle()


func _swing_melee() -> void:
	_attack_hitbox.damage = equipped_weapon.damage if equipped_weapon else attack_damage
	_attack_hitbox.rotation = _last_move_direction.angle()
	_attack_hitbox.monitoring = true
	if OS.is_debug_build():
		_attack_debug_visual.visible = true
	get_tree().create_timer(attack_duration).timeout.connect(_end_attack)


func _end_attack() -> void:
	_attack_hitbox.monitoring = false
	_attack_debug_visual.visible = false


func _process_movement(delta: float) -> void:
	var input_direction := _get_input_direction()

	if input_direction != Vector2.ZERO:
		_last_move_direction = input_direction

	var target_velocity := input_direction * speed
	var rate: float
	if target_velocity.length() > velocity.length():
		rate = acceleration
	elif velocity.length() > speed:
		rate = dash_deceleration # shedding post-dash excess speed, not a normal stop
	else:
		rate = deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_start_dash(input_direction)


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity = _dash_direction * dash_speed

	if _dash_timer <= 0.0:
		_is_dashing = false


func _start_dash(input_direction: Vector2) -> void:
	_dash_direction = input_direction if input_direction != Vector2.ZERO else _last_move_direction
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown


func _get_input_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
