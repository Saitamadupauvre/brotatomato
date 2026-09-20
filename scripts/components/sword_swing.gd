class_name SwordSwing
## Shared swing-glow helper for the melee attack visual (assets/shaders/sword_swing.gdshader).
## Called by whichever script owns the held-item sprite (Player) when it swings.

static func flash(sprite: CanvasItem, duration: float) -> void:
	if sprite == null:
		return
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	if sprite.has_meta("_sword_swing_tween"):
		var existing: Tween = sprite.get_meta("_sword_swing_tween")
		if existing and existing.is_valid():
			existing.kill()
	material.set_shader_parameter("swing_amount", 0.0)
	var tween := sprite.create_tween()
	sprite.set_meta("_sword_swing_tween", tween)
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter("swing_amount", v),
		0.0, 1.0, duration * 0.4
	)
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter("swing_amount", v),
		1.0, 0.0, duration * 0.6
	)
