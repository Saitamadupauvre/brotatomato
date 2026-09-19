class_name ArmorData
extends EquipmentData

## Flat damage reduction. Proposed value, not GDD-fixed — most current
## enemies deal exactly 1 damage, so the default makes basic armor a
## real upgrade against them.
@export var damage_reduction: int = 1
