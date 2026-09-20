class_name ForestSceneKit
extends RefCounted
## Ground/shade/tree/grass building shared by any scene built on a
## DungeonLayout-shaped room (the procedural dungeon, or a trivial
## one-room layout like the camp — see CampLayoutBuilder). Pulled out of
## dungeon.gd so other scenes get the same visuals/behavior for free
## instead of re-deriving them.

const TREE_SCENE: PackedScene = preload("res://scenes/dungeon/tree.tscn")


static func build_ground(ground: ColorRect, layout: DungeonLayout) -> void:
	ground.size = layout.world_size()


## Cartoon forest shadow: darkest at the treeline, fading to full
## brightness `falloff_cells` cells into the open floor.
static func build_shade(shade: ColorRect, layout: DungeonLayout, falloff_cells: int) -> void:
	shade.size = layout.world_size()
	var tex := ImageTexture.create_from_image(ForestDecorator.build_shade_image(layout, falloff_cells))
	(shade.material as ShaderMaterial).set_shader_parameter("density", tex)


## Trees live in a Y-sorted layer with the player: a trunk lower on
## screen than the player draws over them. `trees_root` must itself have
## y_sort_enabled = true (and live under a y-sorted ancestor) for
## individual trees to sort against the player.
static func build_trees(trees_root: Node2D, layout: DungeonLayout, max_depth: int, trees_per_cell: float = 1.0) -> void:
	var placements := ForestDecorator.build(layout, max_depth, trees_per_cell)
	for p in placements:
		var tree: Node2D = TREE_SCENE.instantiate()
		tree.position = p.position
		tree.scale *= p.scale
		if p.flip:
			tree.scale.x = -tree.scale.x
		tree.modulate = Color(p.shade, p.shade, p.shade)
		trees_root.add_child(tree)


## Grass is flat ground decoration under everything that moves, so it
## needs no Y-sort. Wires the player's melee swing to cut it, same as
## the dungeon.
static func build_grass(grass: GrassField, layout: DungeonLayout, density: float, salt: int, player: Node2D) -> void:
	grass.build(ForestDecorator.build_floor_scatter(layout, density, salt), layout.cell_size)
	if player.has_signal("melee_swung"):
		player.melee_swung.connect(grass.cut_around)


static func limit_camera_to_layout(camera: Camera2D, layout: DungeonLayout) -> void:
	var size := layout.world_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	camera.reset_smoothing()
