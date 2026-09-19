class_name WeaponData
extends EquipmentData

enum AttackType { MELEE, RANGED }

@export var attack_type: AttackType
@export var damage: int = 1
@export var attack_cooldown: float = 0.3
