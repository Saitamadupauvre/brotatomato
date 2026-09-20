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
## Burst speed for the dash-strike attack. Separate from the evasion
## dash's dash_speed so combat and movement tuning don't collide.
@export var dash_attack_speed: float = 700.0
## Brief window after taking a hit where further damage is ignored —
## without it, overlapping hitboxes (or one that lingers across physics
## frames) can strip several lives from a single hit.
@export var invincibility_duration: float = 0.4
## How long the teleport-to-camp channel takes to complete (#38). Moving
## or taking damage during the channel cancels it.
@export var teleport_channel_duration: float = 5.0
@export var footstep_interval: float = 0.35
## Radius around the player's feet checked against GrassField for
## standing grass, to pick footsteps_grass vs footsteps_dirt per step.
@export var footstep_grass_check_radius: float = 32.0

## Emitted at the start of a melee swing with the world-space center and
## rough radius of the hitbox, for things that react to a swing without
## needing a hurtbox (grass, breakables).
signal melee_swung(center: Vector2, radius: float)
## Teleport-channel lifecycle events (#38) — VFX (#39) hooks these
## instead of the mechanic re-implementing its own timing.
signal teleport_channel_started
signal teleport_channel_cancelled
signal teleport_channel_completed
## Ammo HUD hooks (#66) — max_ammo 0 means the equipped weapon has no
## magazine (melee, or a RANGED weapon with unlimited ammo like the bow),
## which the HUD reads as "hide the ammo counter".
signal ammo_changed(current: int, max_ammo: int)
signal reload_started
signal reload_ended
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
var _is_dash_attacking: bool = false
var _dash_attack_timer: float = 0.0
var _dash_attack_direction: Vector2 = Vector2.ZERO
## -1 = unlimited (weapon has no magazine, e.g. the bow).
var _current_ammo: int = -1
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _invincible_timer: float = 0.0
var _is_channeling: bool = false
var _channel_timer: float = 0.0
var _footstep_timer: float = 0.0
## Per-card-slot active cooldowns (#7), index-matched to GameState.equipped_cards.
var _card_cooldowns: Array[float] = [0.0, 0.0, 0.0]
## Fixed radius for the Damage Burst card active (#7) — no weapon/range data to derive it from.
const CARD_DAMAGE_BURST_RADIUS: float = 150.0

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
@onready var _camera: Camera2D = $Camera2D
@onready var _sprite_body: Sprite2D = $Sprite/Body

@export var screen_shake_player_hit_strength: float = 14.0
@export var screen_shake_enemy_hit_strength: float = 6.0
@export var screen_shake_duration: float = 0.25
var _shake_timer: float = 0.0
var _shake_strength: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_hurtbox.damage_taken.connect(_on_damage_taken)
	_attack_hitbox.damage = attack_damage
	_attack_hitbox.monitoring = false
	_attack_hitbox.scale = Vector2.ONE * (melee_range / MELEE_SHAPE_REACH)
	GameState.equipment_changed.connect(_on_equipment_changed)
	GameState.active_weapon_changed.connect(_on_active_weapon_changed)
	_sync_active_weapon() # sync held sprite to whatever's already equipped
	CombatFx.hit_landed.connect(_on_combat_hit)


func _on_equipment_changed(slot: EquipmentData.EquipSlot, _item_id: String) -> void:
	if slot == EquipmentData.EquipSlot.WEAPON or slot == EquipmentData.EquipSlot.WEAPON_2:
		if slot == GameState.active_weapon_slot:
			_sync_active_weapon()
	else:
		_recompute_armor_reduction()


func _on_active_weapon_changed(_slot: EquipmentData.EquipSlot) -> void:
	_sync_active_weapon()


## Refreshes held-item sprite, ammo state and equipped_weapon from
## whichever weapon slot is currently active (#50) — shared by both the
## "a weapon slot's contents changed" and "the active slot itself
## swapped" paths, since either can change what's effectively in hand.
func _sync_active_weapon() -> void:
	equipped_weapon = GameState.get_active_weapon() as WeaponData
	_held_item.texture = equipped_weapon.icon if equipped_weapon else null
	_held_item.visible = equipped_weapon != null
	_current_ammo = equipped_weapon.magazine_size if equipped_weapon and equipped_weapon.magazine_size > 0 else -1
	_is_reloading = false
	ammo_changed.emit(max(_current_ammo, 0), equipped_weapon.magazine_size if equipped_weapon else 0)


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
	AudioManager.play(&"hit_impact")
	CombatFx.notify_hit(true)
	HitFlash.flash(_sprite_body)
	GameState.lose_tomato(max(amount - _armor_reduction, 0))
	_invincible_timer = invincibility_duration


func _on_combat_hit(is_player: bool) -> void:
	_shake_strength = screen_shake_player_hit_strength if is_player else screen_shake_enemy_hit_strength
	_shake_timer = screen_shake_duration


func _update_screen_shake(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var falloff := _shake_timer / screen_shake_duration
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * falloff
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
	for i in _card_cooldowns.size():
		if _card_cooldowns[i] > 0.0:
			_card_cooldowns[i] -= delta
	_update_screen_shake(delta)

	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			var needed: int = equipped_weapon.magazine_size - _current_ammo
			var taken: int = min(needed, GameState.get_item_count("ammo"))
			GameState.remove_item("ammo", taken)
			_current_ammo += taken
			_is_reloading = false
			reload_ended.emit()
			ammo_changed.emit(_current_ammo, equipped_weapon.magazine_size)

	if _is_channeling:
		_process_teleport_channel(delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _is_dash_attacking:
		_process_dash_attack(delta)
	elif _is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack()

	if Input.is_action_just_pressed("teleport"):
		_start_teleport_channel()

	if Input.is_action_just_pressed("reload") and _can_reload():
		_start_reload()

	if Input.is_action_just_pressed("swap_weapon"):
		GameState.swap_active_weapon()

	for i in GameState.CARD_SLOTS:
		if Input.is_action_just_pressed("card_active_%d" % (i + 1)):
			_try_trigger_card_active(i)

	move_and_slide()
	if _last_move_direction.x != 0.0:
		$Sprite.scale.x = 1.0 if _last_move_direction.x < 0.0 else -1.0

	var target_animation := "run" if velocity.length() > 5.0 else "idle"
	if _animation_player.current_animation != target_animation:
		_animation_player.play(target_animation)

	_process_footsteps(delta, target_animation == "run")


func _process_footsteps(delta: float, is_moving: bool) -> void:
	if not is_moving or _is_dashing or _is_dash_attacking or _is_channeling:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		var grass_field: GrassField = get_tree().get_first_node_in_group("grass_field")
		var on_grass := grass_field != null and grass_field.has_grass_near(global_position, footstep_grass_check_radius)
		AudioManager.play(&"footsteps_grass" if on_grass else &"footsteps_dirt")
		_footstep_timer = footstep_interval


## Card active dispatch (#7) — slot is an index into GameState.equipped_cards,
## gated by this slot's own cooldown (set from the card's active_cooldown).
func _try_trigger_card_active(slot: int) -> void:
	if _card_cooldowns[slot] > 0.0:
		return
	var item_id: String = GameState.equipped_cards[slot]
	if item_id == "":
		return
	var card: CardData = GameState.get_item_data(item_id) as CardData
	if card == null:
		return
	_card_cooldowns[slot] = card.active_cooldown
	match card.active:
		CardData.Active.INSTANT_HARVEST:
			_trigger_instant_harvest()
		CardData.Active.DAMAGE_BURST:
			_trigger_damage_burst(card.active_value)
		CardData.Active.DASH_RESET:
			_dash_cooldown_timer = 0.0
		CardData.Active.GOLD_RUSH:
			GameState.add_item("gold", int(card.active_value))


func _trigger_instant_harvest() -> void:
	var nearest: Node = null
	var nearest_dist: float = INF
	for plot in get_tree().get_nodes_in_group("plot_behavior"):
		if not plot.is_growing():
			continue
		var dist: float = plot.owner_entity.global_position.distance_squared_to(global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = plot
	if nearest:
		nearest.force_ripen()


func _trigger_damage_burst(amount: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.global_position.distance_to(global_position) <= CARD_DAMAGE_BURST_RADIUS:
			enemy.health.take_damage(int(amount))


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
			ammo_changed.emit(_current_ammo, equipped_weapon.magazine_size)
			if _current_ammo <= 0:
				_start_reload()
	elif equipped_weapon and equipped_weapon.attack_type == WeaponData.AttackType.DASH:
		_start_dash_attack()
	else:
		_swing_melee()


func _fire_projectile() -> void:
	AudioManager.play(&"ranged_fire")
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.damage = int(equipped_weapon.damage * GameState.get_passive_multiplier(CardData.Passive.PLAYER_DAMAGE))
	projectile.speed = equipped_weapon.projectile_speed
	projectile.target_mask = ENEMY_HURTBOX_MASK
	get_parent().add_child(projectile)
	projectile.position = position
	projectile.rotation = _get_aim_direction().angle()


func _can_reload() -> bool:
	return equipped_weapon != null and equipped_weapon.magazine_size > 0 \
		and not _is_reloading and _current_ammo < equipped_weapon.magazine_size \
		and GameState.get_item_count("ammo") > 0


## No-ops if the reserve ammo pool is empty — weapon just stays dry until
## a pickup restocks it, rather than refilling for free.
func _start_reload() -> void:
	if GameState.get_item_count("ammo") <= 0:
		return
	AudioManager.play(&"reload")
	_is_reloading = true
	_reload_timer = equipped_weapon.reload_time
	reload_started.emit()


func _swing_melee() -> void:
	AudioManager.play(&"melee_swing")
	var aim_direction := _get_aim_direction()
	var range_scale := melee_range / MELEE_SHAPE_REACH
	_attack_hitbox.damage = int((equipped_weapon.damage if equipped_weapon else attack_damage) * GameState.get_passive_multiplier(CardData.Passive.PLAYER_DAMAGE))
	_attack_hitbox.rotation = aim_direction.angle()
	_attack_hitbox.monitoring = true
	melee_swung.emit(global_position + aim_direction * MELEE_REACH * range_scale, MELEE_RADIUS * range_scale)
	if OS.is_debug_build():
		_attack_debug_visual.visible = true
	get_tree().create_timer(attack_duration).timeout.connect(_end_attack)


func _start_dash_attack() -> void:
	AudioManager.play(&"dash_attack")
	var aim_direction := _get_aim_direction()
	_is_dash_attacking = true
	_dash_attack_timer = attack_duration
	_dash_attack_direction = aim_direction
	_attack_hitbox.damage = int((equipped_weapon.damage if equipped_weapon else attack_damage) * GameState.get_passive_multiplier(CardData.Passive.PLAYER_DAMAGE))
	_attack_hitbox.rotation = aim_direction.angle()
	_attack_hitbox.monitoring = true
	if OS.is_debug_build():
		_attack_debug_visual.visible = true
	get_tree().create_timer(attack_duration).timeout.connect(_end_attack)


func _process_dash_attack(delta: float) -> void:
	_dash_attack_timer -= delta
	velocity = _dash_attack_direction * dash_attack_speed
	if _dash_attack_timer <= 0.0:
		_is_dash_attacking = false


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
	var target_velocity := input_direction * speed * speed_multiplier * GameState.get_passive_multiplier(CardData.Passive.PLAYER_SPEED)
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
	AudioManager.play(&"player_dash")
	_dash_direction = input_direction if input_direction != Vector2.ZERO else _last_move_direction
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown


func _get_input_direction() -> Vector2:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
