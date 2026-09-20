class_name HitFlash
## Shared white-flash helper for damage feedback (assets/shaders/hit_flash.gdshader).
## Called by whichever script owns the sprite (Enemy, Player) when its own
## hurtbox reports damage — never by the attacker.

static func flash(sprite: CanvasItem, duration: float = 0.25) -> void:
	if sprite == null:
		return
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	# Kill any fade already in flight so rapid hits restart from full white
	# instead of fighting the previous tween (looked like a stuck flash).
	if sprite.has_meta("_hit_flash_tween"):
		var existing: Tween = sprite.get_meta("_hit_flash_tween")
		if existing and existing.is_valid():
			existing.kill()
	material.set_shader_parameter("flash_amount", 1.0)
	var tween := sprite.create_tween()
	sprite.set_meta("_hit_flash_tween", tween)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter("flash_amount", v),
		1.0, 0.0, duration
	)
