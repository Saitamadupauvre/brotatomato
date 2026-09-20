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
## Movement speed multiplier applied while an attack is in progress (GDD has
## no fixed number for this).
@export var attack_move_speed_multiplier: float = 0.2
## Tip-to-player distance of the melee hitbox, in px. AttackHitboxShape's
## polygon is authored with a 42px reach; this scales it uniformly.
@export var melee_range: float = 58.0
## Brief window after taking a hit where further damage is ignored —
## without it, overlapping hitboxes (or one that lingers across physics
## frames) can strip several lives from a single hit.
@export var invincibility_duration: float = 0.4
## How long the teleport-to-camp channel takes to complete (#38). Moving
## or taking damage during the channel cancels it.
@export var teleport_channel_duration: float = 5.0

## Emitted at the start of a melee swing with the world-space center and
## rough radius of the hitbox, for things that react to a swing without
## needing a hurtbox (grass, breakables).
signal melee_swung(center: Vector2, radius: float)
## Teleport-channel lifecycle events (#38) — VFX (#39) hooks these
## instead of the mechanic re-implementing its own timing.
signal teleport_channel_started
signal teleport_channel_cancelled
signal teleport_channel_completed
## AttackHitboxShape's authored (unscaled) reach, in px.
const MELEE_SHAPE_REACH: float = 42.0
## Distance from the player to the center of the melee arc, and its
## radius, at the authored (unscaled) reach. Approximates AttackHitboxShape's polygon.
const MELEE_REACH: float = 24.0
const MELEE_RADIUS: float = 30.0

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/dungeon/projectile.tscn")
const ENEMY_HURTBOX_MASK: int = 8

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _last_move_direction: Vector2 = Vector2.DOWN
var _attack_cooldown_timer: float = 0.0
var _is_attacking: bool = false
## -1 = unlimited (weapon has no magazine, e.g. the bow).
var _current_ammo: int = -1
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _invincible_timer: float = 0.0
var _is_channeling: bool = false
var _channel_timer: float = 0.0

var equipped_weapon: WeaponData = null
var _armor_reduction: int = 0

@onready var _hurtbox: HurtboxComponent = $Hurtbox
@onready var _attack_hitbox: HitboxComponent = $AttackHitbox
@onready var _attack_debug_visual: CanvasItem = $AttackHitbox/DebugVisual
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _channel_bar: ProgressBar = $ChannelBar
@onready var _teleport_glow: ColorRect = $TeleportGlow
@onready var _teleport_particles: GPUParticles2D = $TeleportParticles
@onready var _held_item: Sprite2D = $Sprite/HeldItem


func _ready() -> void:
	add_to_group("player")
	_hurtbox.damage_taken.connect(_on_damage_taken)
	_attack_hitbox.damage = attack_damage
	_attack_hitbox.monitoring = false
	_attack_hitbox.scale = Vector2.ONE * (melee_range / MELEE_SHAPE_REACH)
	GameState.equipment_changed.connect(_on_equipment_changed)
	_on_equipment_changed(EquipmentData.EquipSlot.WEAPON, "") # sync held sprite to whatever's already equipped


func _on_equipment_changed(slot: EquipmentData.EquipSlot, _item_id: String) -> void:
	if slot == EquipmentData.EquipSlot.WEAPON:
		equipped_weapon = GameState.get_equipped(slot) as WeaponData
		_held_item.texture = equipped_weapon.icon if equipped_weapon else null
		_held_item.visible = equipped_weapon != null
		_current_ammo = equipped_weapon.magazine_size if equipped_weapon and equipped_weapon.magazine_size > 0 else -1
		_is_reloading = false
	else:
		_recompute_armor_reduction()


func _recompute_armor_reduction() -> void:
	_armor_reduction = 0
	for armor_slot in EquipmentData.ARMOR_SLOTS:
		var armor := GameState.get_equipped(armor_slot) as ArmorData
		if armor:
			_armor_reduction += armor.damage_reduction


func _on_damage_taken(amount: int) -> void:
	if _is_channeling:
		_cancel_teleport_channel()
	if _invincible_timer > 0.0:
		return
	GameState.lose_tomato(max(amount - _armor_reduction, 0))
	_invincible_timer = invincibility_duration


func _physics_process(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	if _invincible_timer > 0.0:
		_invincible_timer -= delta

	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_current_ammo = equipped_weapon.magazine_size
			_is_reloading = false

	if _is_channeling:
		_process_teleport_channel(delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack()

	if Input.is_action_just_pressed("teleport"):
		_start_teleport_channel()

	if Input.is_action_just_pressed("reload") and _can_reload():
		_start_reload()

	move_and_slide()
	if _last_move_direction.x != 0.0:
		$Sprite.scale.x = 1.0 if _last_move_direction.x < 0.0 else -1.0

	var target_animation := "run" if velocity.length() > 5.0 else "idle"
	if _animation_player.current_animation != target_animation:
		_animation_player.play(target_animation)


func _start_teleport_channel() -> void:
	_is_channeling = true
	_channel_timer = teleport_channel_duration
	_channel_bar.max_value = teleport_channel_duration
	_channel_bar.value = 0.0
	_channel_bar.visible = true
	_teleport_glow.visible = true
	_teleport_particles.emitting = true
	teleport_channel_started.emit()


func _process_teleport_channel(delta: float) -> void:
	if _get_input_direction() != Vector2.ZERO:
		_cancel_teleport_channel()
		return

	_channel_timer -= delta
	_channel_bar.value = teleport_channel_duration - _channel_timer

	if _channel_timer <= 0.0:
		_complete_teleport_channel()


func _cancel_teleport_channel() -> void:
	_is_channeling = false
	_channel_bar.visible = false
	_stop_teleport_vfx()
	teleport_channel_cancelled.emit()


func _complete_teleport_channel() -> void:
	_is_channeling = false
	_channel_bar.visible = false
	_stop_teleport_vfx()
	teleport_channel_completed.emit()
	SceneRouter.go_to_camp()


func _stop_teleport_vfx() -> void:
	_teleport_glow.visible = false
	_teleport_particles.emitting = false


func _start_attack() -> void:
	var is_gun := equipped_weapon and equipped_weapon.attack_type == WeaponData.AttackType.RANGED and equipped_weapon.magazine_size > 0
	if is_gun and (_is_reloading or _current_ammo <= 0):
		return # empty or mid-reload: attack press does nothing (no cooldown spent)

	var cooldown: float = equipped_weapon.attack_cooldown if equipped_weapon else attack_cooldown
	_attack_cooldown_timer = cooldown
	_is_attacking = true
	get_tree().create_timer(attack_duration).timeout.connect(func() -> void: _is_attacking = false)

	if equipped_weapon and equipped_weapon.attack_type == WeaponData.AttackType.RANGED:
		_fire_projectile()
		if is_gun:
			_current_ammo -= 1
			if _current_ammo <= 0:
				_start_reload()
	else:
		_swing_melee()


func _fire_projectile() -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.damage = equipped_weapon.damage
	projectile.target_mask = ENEMY_HURTBOX_MASK
	get_parent().add_child(projectile)
	projectile.position = position
	projectile.rotation = _get_aim_direction().angle()


func _can_reload() -> bool:
	return equipped_weapon != null and equipped_weapon.magazine_size > 0 \
		and not _is_reloading and _current_ammo < equipped_weapon.magazine_size


func _start_reload() -> void:
	_is_reloading = true
	_reload_timer = equipped_weapon.reload_time


func _swing_melee() -> void:
	var aim_direction := _get_aim_direction()
	var range_scale := melee_range / MELEE_SHAPE_REACH
	_attack_hitbox.damage = equipped_weapon.damage if equipped_weapon else attack_damage
	_attack_hitbox.rotation = aim_direction.angle()
	_attack_hitbox.monitoring = true
	melee_swung.emit(global_position + aim_direction * MELEE_REACH * range_scale, MELEE_RADIUS * range_scale)
	if OS.is_debug_build():
		_attack_debug_visual.visible = true
	get_tree().create_timer(attack_duration).timeout.connect(_end_attack)


func _get_aim_direction() -> Vector2:
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction != Vector2.ZERO else _last_move_direction


func _end_attack() -> void:
	_attack_hitbox.monitoring = false
	_attack_debug_visual.visible = false


func _process_movement(delta: float) -> void:
	var input_direction := _get_input_direction()

	if input_direction != Vector2.ZERO:
		_last_move_direction = input_direction

	var speed_multiplier := attack_move_speed_multiplier if _is_attacking else 1.0
	var target_velocity := input_direction * speed * speed_multiplier
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
