class_name EquipmentData
extends ItemData
## Base for equippable items (weapons, armor). Still an ordinary ItemData
## as far as the inventory count system is concerned — equipping just
## marks which owned item id occupies a slot, see GameState.equip_item.

enum EquipSlot { WEAPON, HELMET, CHESTPLATE, LEGGINGS, BOOTS }

const ARMOR_SLOTS: Array[EquipSlot] = [EquipSlot.HELMET, EquipSlot.CHESTPLATE, EquipSlot.LEGGINGS, EquipSlot.BOOTS]
const ALL_SLOTS: Array[EquipSlot] = [EquipSlot.WEAPON, EquipSlot.HELMET, EquipSlot.CHESTPLATE, EquipSlot.LEGGINGS, EquipSlot.BOOTS]

@export var slot: EquipSlot
