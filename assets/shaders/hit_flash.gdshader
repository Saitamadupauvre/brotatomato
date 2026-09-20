shader_type canvas_item;
// Whitens a sprite on hit. modulate can only darken (it multiplies), so
// getting a true white flash needs a texture-color/white mix instead.

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), flash_amount), tex.a * COLOR.a);
}
