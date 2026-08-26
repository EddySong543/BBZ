shader_type canvas_item;
render_mode unshaded;

// Rear shallows of the same spring pool. It shares the foreground emerald
// palette and source-centred timing, with finer, lower-amplitude marks.

group_uniforms layout;
uniform vec2 size_px = vec2(480.0, 29.0);
uniform float px_size : hint_range(1.0, 4.0) = 1.0;
uniform float perspective_y : hint_range(1.0, 6.0) = 3.2;
uniform vec2 local_origin = vec2(-32.0, 644.0);
uniform vec2 local_extent = vec2(1984.0, 116.0);
group_uniforms;

varying vec2 local_position;
varying float shoreline_depth;

group_uniforms palette;
uniform vec4 surface_color : source_color = vec4(0.133, 0.667, 0.6, 1.0);
uniform vec4 mid_color : source_color = vec4(0.133, 0.533, 0.533, 1.0);
uniform vec4 deep_color : source_color = vec4(0.067, 0.267, 0.4, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.333, 0.8, 0.667, 1.0);
uniform vec4 spring_glow_color : source_color = vec4(0.44, 0.88, 0.72, 1.0);
uniform vec4 shore_contact_color : source_color = vec4(0.012, 0.15, 0.20, 1.0);
uniform vec4 distance_atmosphere_color : source_color = vec4(0.20, 0.38, 0.40, 1.0);
uniform float distance_atmosphere : hint_range(0.0, 0.4) = 0.10;
group_uniforms;

group_uniforms spring_motion;
uniform float anim_fps : hint_range(1.0, 12.0) = 8.0;
uniform vec2 main_source = vec2(0.52, 0.06);
uniform vec2 secondary_source_a = vec2(0.20, 0.58);
uniform vec2 secondary_source_b = vec2(0.82, 0.50);
uniform float main_period_sec : hint_range(2.0, 12.0) = 7.2;
uniform float micro_period_sec : hint_range(3.0, 16.0) = 10.8;
uniform float ring_spacing : hint_range(0.08, 0.6) = 0.34;
uniform float ring_width : hint_range(0.005, 0.08) = 0.032;
uniform float main_ring_strength : hint_range(0.0, 1.0) = 0.44;
uniform float micro_ring_strength : hint_range(0.0, 1.0) = 0.10;
uniform float caustic_strength : hint_range(0.0, 0.5) = 0.11;
uniform float glint_period_sec : hint_range(4.0, 16.0) = 10.2;
uniform float glint_cell_px : hint_range(12.0, 96.0) = 36.0;
uniform float glint_presence : hint_range(0.0, 1.0) = 0.30;
uniform float glint_strength : hint_range(0.0, 0.5) = 0.15;
uniform float diagnostic_time_sec = -1.0;
group_uniforms;

group_uniforms shore;
uniform float shore_shadow_px : hint_range(0.0, 4.0) = 1.0;
uniform float shore_glow_density : hint_range(0.0, 0.8) = 0.24;
uniform float shore_glow_strength : hint_range(0.0, 0.8) = 0.26;
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 251.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float motion_time() {
	return diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
}


float spring_distance(vec2 uv, vec2 source) {
	return length((uv - source) * vec2(1.0, perspective_y));
}


float ring_mask(float distance_to_source, float time_phase, float phase_offset) {
	float phase = fract(
			distance_to_source / max(ring_spacing, 0.001)
			- time_phase + phase_offset);
	float edge_distance = min(phase, 1.0 - phase);
	return 1.0 - smoothstep(ring_width, ring_width + 0.040, edge_distance);
}


float arc_modulation(vec2 uv, vec2 source, float distance_to_source) {
	vec2 delta = uv - source;
	float angle = atan(delta.y, delta.x);
	float ring_id = floor(distance_to_source / max(ring_spacing, 0.001));
	float broad_arc = 0.5 + 0.5 * sin(angle * 3.0 + ring_id * 1.73);
	return mix(0.66, 1.0, smoothstep(0.16, 0.84, broad_arc));
}


void vertex() {
	// Position keeps the pool on one horizontal phase and lets fragment depth
	// follow the exact authored polygon contour. Vertex color R is authored as
	// zero at every shore vertex and one at the two submerged bottom vertices;
	// unlike Polygon2D UVs, vertex color interpolation is reliable here.
	local_position = VERTEX;
	shoreline_depth = COLOR.r;
}


void fragment() {
	float t = floor(motion_time() * anim_fps) / anim_fps;
	float local_x = clamp(
			(local_position.x - local_origin.x) / max(local_extent.x, 1.0),
			0.0, 1.0);
	float shore_depth_px = clamp(shoreline_depth, 0.0, 1.0) * size_px.y;
	vec2 px = vec2(
			floor(local_x * size_px.x / px_size) * px_size + px_size * 0.5,
			floor(shore_depth_px / px_size) * px_size + px_size * 0.5);
	vec2 quv = px / size_px;
	float depth = clamp(quv.y, 0.0, 1.0);

	vec3 col = mix(
			surface_color.rgb, mid_color.rgb, smoothstep(0.0, 0.76, depth));
	float deep_mix = smoothstep(0.80, 1.0, depth) * 0.56;
	col = mix(col, deep_color.rgb, deep_mix);
	// The distant pool is the same water under oasis air, not a separate dark
	// plane.  The shared atmosphere is strongest at the rear bank and releases
	// toward the platform.
	float distance_air = mix(1.0, 0.36, smoothstep(0.0, 0.86, depth));
	col = mix(
			col, distance_atmosphere_color.rgb,
			distance_air * distance_atmosphere);

	float main_distance = spring_distance(quv, main_source);
	float main_time = t / max(main_period_sec, 0.001);
	float ring_envelope = 1.0 - smoothstep(0.28, 2.05, main_distance);
	float crest = ring_mask(main_distance, main_time, 0.0)
			* arc_modulation(quv, main_source, main_distance)
			* ring_envelope;
	float trough = ring_mask(main_distance, main_time, 0.12) * ring_envelope;
	col = mix(col, deep_color.rgb, trough * 0.08);
	col = mix(col, ripple_color.rgb, crest * main_ring_strength);

	float micro_time = t / max(micro_period_sec, 0.001);
	float secondary_distance_a = spring_distance(quv, secondary_source_a);
	float secondary_distance_b = spring_distance(quv, secondary_source_b);
	float secondary_a = ring_mask(
			secondary_distance_a * 1.72, micro_time, 0.21)
			* (1.0 - smoothstep(0.05, 0.62, secondary_distance_a));
	float secondary_b = ring_mask(
			secondary_distance_b * 1.58, micro_time * 0.89, 0.67)
			* (1.0 - smoothstep(0.05, 0.58, secondary_distance_b));
	float secondary_rings = max(secondary_a, secondary_b);
	col = mix(col, ripple_color.rgb,
			secondary_rings * micro_ring_strength);

	float caustic_phase = t / max(micro_period_sec, 0.001) * TAU;
	float caustic_a = sin((quv.x * 5.2 + quv.y * 2.4) * TAU
			+ sin(quv.y * 6.0 * TAU) * 0.35 + caustic_phase);
	float caustic_b = sin((quv.x * -3.0 + quv.y * 5.1) * TAU
			- caustic_phase * 0.71);
	float caustic = smoothstep(1.50, 1.84, caustic_a + caustic_b);
	caustic *= smoothstep(0.05, 0.24, depth)
			* (1.0 - smoothstep(0.80, 1.0, depth));
	col = mix(col, spring_glow_color.rgb, caustic * caustic_strength);

	float glint_cell = floor(px.x / max(glint_cell_px, px_size));
	float glint_row_id = floor(px.y / max(px_size * 2.0, 1.0));
	float glint_seed = hash21(vec2(glint_cell, glint_row_id + 149.0));
	float glint_active = step(1.0 - glint_presence, glint_seed);
	float glint_phase = t * TAU / max(glint_period_sec, 0.001)
			+ glint_seed * TAU;
	float glint_pulse = floor(
			(0.5 + 0.5 * sin(glint_phase)) * 4.0 + 0.5) / 4.0;
	float glint_local_x = mod(px.x, max(glint_cell_px, px_size));
	float glint_length = max(glint_cell_px, px_size)
			* mix(0.22, 0.46, hash21(vec2(glint_cell, 193.0)));
	float glint_segment = step(glint_local_x, glint_length);
	float glint_row = step(0.56,
			hash21(vec2(glint_cell + 31.0, glint_row_id + 229.0)));
	float glint_depth = smoothstep(0.08, 0.28, depth)
			* (1.0 - smoothstep(0.80, 0.98, depth));
	float glint = glint_active * glint_segment * glint_row
			* glint_pulse * glint_depth;
	vec3 glint_color = mix(ripple_color.rgb, spring_glow_color.rgb, 0.38);
	col = mix(col, glint_color, glint * glint_strength);

	float source_glow = 1.0 - smoothstep(0.0, 0.18, main_distance);
	col = mix(col, spring_glow_color.rgb, source_glow * 0.20);

	float shore_shadow = 1.0 - step(
			shore_shadow_px + px_size, shore_depth_px);
	col = mix(col, shore_contact_color.rgb, shore_shadow * 0.54);
	float shore_cell_w = 36.0;
	float shore_cell = floor(px.x / shore_cell_w);
	float shore_local = mod(px.x, shore_cell_w);
	float shore_active = step(
			1.0 - shore_glow_density, hash21(vec2(shore_cell, 211.0)));
	float shore_pulse = floor((0.5 + 0.5 * sin(
			t / 9.2 * TAU + hash21(vec2(shore_cell, 307.0)) * TAU))
			* 3.0 + 0.5) / 3.0;
	float shore_segment = shore_active * step(shore_local, shore_cell_w * 0.38);
	float shore_row = (1.0 - step(px_size * 1.5, shore_depth_px)) * shore_segment;
	col = mix(
			col,
			spring_glow_color.rgb,
			shore_row * shore_pulse * shore_glow_strength);

	col = floor(clamp(col, vec3(0.0), vec3(1.0)) * 31.0 + 0.5) / 31.0;
	COLOR = vec4(col, 1.0);
}
