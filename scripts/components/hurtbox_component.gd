class_name HurtboxComponent
extends Area2D

signal damage_taken(amount: int)

func take_damage(amount: int) -> void:
	damage_taken.emit(amount)
