class_name DialogueData
extends Resource
## A sequence of DialogueLine played in order. Instances live as .tres in
## resources/dialogue/ — new dialogue is "duplicate a .tres, edit lines."

@export var lines: Array[DialogueLine] = []
