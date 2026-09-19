shader_type canvas_item;
// Masks a SubViewportContainer's composited output to a soft-edged
// circle (MINI) or leaves it untouched (FULL, plain rectangle).

uniform bool circular = true;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float alpha = tex_color.a;
	if (circular) {
		float dist = length(UV - vec2(0.5));
		alpha *= 1.0 - smoothstep(0.46, 0.5, dist);
	}
	COLOR = vec4(tex_color.rgb, alpha);
}
