class_name MapPoi
extends RefCounted
## One trackable point of interest for the minimap/full map: an enemy or
## a container, following its live node so a dead enemy's icon
## disappears with it. Built by dungeon.gd right after _populate().

enum Kind { ENEMY, CHEST, ALTAR }

var node: Node2D
var kind: Kind


func _init(poi_node: Node2D, poi_kind: Kind) -> void:
	node = poi_node
	kind = poi_kind
