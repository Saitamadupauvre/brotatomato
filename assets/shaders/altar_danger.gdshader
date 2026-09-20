// Telegraph pulse for an altar about to spawn its wave. `urgency` ramps
// 0->1 over the telegraph countdown (driven by AltarBehavior via tween);
// both the red mix strength and the blink speed scale with it, so the
// altar reads as calm at first and frantic right before enemies land.
shader_type canvas_item;

uniform float urgency : hint_range(0.0, 1.0) = 0.0;
uniform vec4 danger_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float pulse_speed = 10.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed * urgency);
	vec3 col = mix(tex.rgb, danger_color.rgb, urgency * pulse * 0.85);
	COLOR = vec4(col, tex.a * COLOR.a);
}
