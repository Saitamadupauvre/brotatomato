extends Node
## Central combat-feedback hub. HealthComponent (enemies) and Player each
## report a landed hit here instead of reaching for the camera/sprite
## directly — keeps screen shake and hit-flash decoupled from whoever
## dealt or took the damage.

signal hit_landed(is_player: bool)


func notify_hit(is_player: bool) -> void:
	hit_landed.emit(is_player)
