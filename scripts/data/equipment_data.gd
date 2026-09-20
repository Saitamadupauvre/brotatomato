class_name EquipmentData
extends ItemData
## Base for equippable items (weapons, armor). Still an ordinary ItemData
## as far as the inventory count system is concerned — equipping just
## marks which owned item id occupies a slot, see GameState.equip_item.

## WEAPON_2 is a second physical weapon slot, not a distinct item category —
## weapon resources are still authored with slot = WEAPON; which of the two
## a weapon lands in is chosen at equip time (see GameState.equip_item's
## target_slot param), not by the item's own data.
enum EquipSlot { WEAPON, WEAPON_2, HELMET, CHESTPLATE, LEGGINGS, BOOTS }

const ARMOR_SLOTS: Array[EquipSlot] = [EquipSlot.HELMET, EquipSlot.CHESTPLATE, EquipSlot.LEGGINGS, EquipSlot.BOOTS]
const ALL_SLOTS: Array[EquipSlot] = [EquipSlot.WEAPON, EquipSlot.WEAPON_2, EquipSlot.HELMET, EquipSlot.CHESTPLATE, EquipSlot.LEGGINGS, EquipSlot.BOOTS]

@export var slot: EquipSlot
