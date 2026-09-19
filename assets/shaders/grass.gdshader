// Grass tuft vertex shader for a MultiMeshInstance2D.
// Base of the quad (UV.y = 1) stays pinned; tips (UV.y = 0) get:
//   - idle wind sway (sin of time + world x)
//   - a push away from `player_pos` inside `push_radius`
//   - collapse when cut, then regrow over time.
// Cut state comes from per-instance custom data set by GrassField:
//   INSTANCE_CUSTOM.x = time the tuft was cut (in GrassField's clock)
//   INSTANCE_CUSTOM.y = 1.0 if cut, 0.0 if never cut
// `now` is that same clock, pushed as a uniform every frame, so shader
// and script never disagree about elapsed time.
shader_type canvas_item;

uniform vec2 player_pos = vec2(-100000.0);
uniform float now = 0.0;
uniform float push_radius = 56.0;
uniform float push_strength = 18.0;
uniform float sway_strength = 4.0;
uniform float sway_speed = 1.6;
// Seconds a cut tuft stays flat before it starts growing back, and how
// long the regrow takes.
uniform float regrow_delay = 20.0;
uniform float regrow_duration = 10.0;
// Half the quad height in mesh units (set by GrassField from the texture).
uniform float half_height = 350.0;

void vertex() {
	float tip = 1.0 - UV.y; // 0 at base, 1 at tips
	// Per-tuft anchor (the base point), so every vertex of a tuft agrees
	// on distance to the player and on sway phase.
	vec2 world = (MODEL_MATRIX * vec4(0.0, -half_height, 0.0, 1.0)).xy;

	// Cut: shrink toward the base. growth 0 = flat, 1 = full height.
	float growth = 1.0;
	if (INSTANCE_CUSTOM.y > 0.5) {
		float age = now - INSTANCE_CUSTOM.x;
		growth = smoothstep(regrow_delay, regrow_delay + regrow_duration, age);
		// Keep a stub so the cut spot still reads as grass.
		growth = mix(0.15, 1.0, growth);
	}

	float sway = sin(now * sway_speed + world.x * 0.05 + world.y * 0.02) * sway_strength;

	vec2 away = world - player_pos;
	float d = length(away);
	// smoothstep needs edge0 < edge1 (undefined otherwise), so invert.
	float push = (1.0 - smoothstep(0.0, push_radius, d)) * push_strength;
	vec2 push_dir = d > 0.001 ? away / d : vec2(1.0, 0.0);

	// Displacement is computed in world space, then brought back to
	// instance space so flipped/scaled tufts bend the right way.
	vec2 world_offset = vec2(sway, 0.0) + push_dir * push;
	mat2 to_local = inverse(mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy));
	vec2 local_offset = to_local * world_offset;

	// Scale height around the base. The instance y scale is negative
	// (see GrassField.build), so the on-screen bottom is mesh -half_height.
	float base_y = -half_height;
	VERTEX.y = base_y + (VERTEX.y - base_y) * growth;
	VERTEX += local_offset * tip * growth;
}
