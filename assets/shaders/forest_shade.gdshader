// Cartoon shadow overlay for the dungeon. `density` is one texel per
// layout cell (0 = open, 1 = deep forest), sampled with linear filtering
// so it ramps smoothly, then snapped to `levels` hard steps for a
// cel-shaded look. Multiplied over the scene (blend_mul), so 1.0 = no
// darkening and `shade_color` = darkest band.
shader_type canvas_item;
render_mode blend_mul;

uniform sampler2D density : filter_linear, repeat_disable;
uniform int levels = 10;
uniform vec4 shade_color : source_color = vec4(0.25, 0.28, 0.4, 1.0);
// Cap so even solid forest keeps some detail visible.
uniform float max_darkness = 0.75;

void fragment() {
	float d = texture(density, UV).r;
	float stepped = floor(d * float(levels) + 0.5) / float(levels);
	float amount = clamp(stepped, 0.0, 1.0) * max_darkness;
	COLOR = vec4(mix(vec3(1.0), shade_color.rgb, amount), 1.0);
}
