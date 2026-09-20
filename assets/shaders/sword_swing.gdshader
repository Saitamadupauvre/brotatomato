shader_type canvas_item;
// Brightens the blade tip while swing_amount ramps 0->1->0, faking motion
// blur/glow on a fast weapon swing without a real trail-particle system.

uniform float swing_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float streak = smoothstep(0.2, 1.0, UV.x) * swing_amount;
	COLOR = vec4(tex.rgb + vec3(streak), tex.a * COLOR.a);
}
