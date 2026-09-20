class_name WeaponData
extends EquipmentData

enum AttackType { MELEE, RANGED }

@export var attack_type: AttackType
@export var damage: int = 1
## Fire rate for RANGED weapons: minimum time between shots.
@export var attack_cooldown: float = 0.3
## Projectile travel speed for RANGED weapons (px/s).
@export var projectile_speed: float = 300.0
## Gun magazine size. 0 = no magazine (unlimited shots, e.g. the bow) —
## only RANGED weapons with a positive value ever reload.
@export var magazine_size: int = 0
@export var reload_time: float = 1.0
