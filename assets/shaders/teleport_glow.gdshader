// Pulsing radial glow for the teleport-to-camp channel (#39).
// Drawn on a square CanvasItem centered on the player; UV is remapped so
// (0,0) sits at the center instead of the corner.
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float pulse_speed = 3.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	float ring = 1.0 - smoothstep(0.0, 1.0, dist);
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	COLOR = vec4(glow_color.rgb, ring * pulse * glow_color.a);
}
