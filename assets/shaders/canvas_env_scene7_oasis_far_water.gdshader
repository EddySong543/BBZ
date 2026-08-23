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

group_uniforms palette;
uniform vec4 surface_color : source_color = vec4(0.018, 0.66, 0.58, 1.0);
uniform vec4 mid_color : source_color = vec4(0.004, 0.47, 0.47, 1.0);
uniform vec4 deep_color : source_color = vec4(0.0, 0.23, 0.33, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.20, 0.91, 0.70, 1.0);
uniform vec4 spring_glow_color : source_color = vec4(0.44, 1.0, 0.78, 1.0);
uniform vec4 bank_shadow_color : source_color = vec4(0.002, 0.10, 0.15, 1.0);
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
	// Polygon2D has no texture. Its interpolated position is the stable UV source.
	local_position = VERTEX;
}


void fragment() {
	float t = floor(TIME * anim_fps) / anim_fps;
	vec2 local_uv = clamp(
			(local_position - local_origin) / max(local_extent, vec2(1.0)),
			vec2(0.0),
			vec2(1.0));
	vec2 px = floor(local_uv * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;
	float depth = clamp(quv.y, 0.0, 1.0);

	vec3 col = mix(surface_color.rgb, mid_color.rgb, smoothstep(0.0, 0.58, depth));
	col = mix(col, deep_color.rgb, smoothstep(0.54, 1.0, depth));
	// Stable reflected-bank columns keep the rear pool from reading as flat fill.
	float column = floor(px.x / 17.0);
	float reflected_bank = hash21(vec2(column, 43.0));
	reflected_bank = smoothstep(0.38, 0.78, reflected_bank)
			* (1.0 - smoothstep(0.18, 0.92, depth));
	col = mix(col, bank_shadow_color.rgb, reflected_bank * 0.16);

	float main_distance = spring_distance(quv, main_source);
	float main_time = t / max(main_period_sec, 0.001);
	float ring_envelope = 1.0 - smoothstep(0.28, 2.05, main_distance);
	float crest = ring_mask(main_distance, main_time, 0.0)
			* arc_modulation(quv, main_source, main_distance)
			* ring_envelope;
	float trough = ring_mask(main_distance, main_time, 0.12) * ring_envelope;
	col = mix(col, deep_color.rgb, trough * 0.08);
	col = mix(col, ripple_color.rgb, crest * main_ring_strength);

	float caustic_phase = t / max(micro_period_sec, 0.001) * TAU;
	float caustic_a = sin((quv.x * 5.2 + quv.y * 2.4) * TAU
			+ sin(quv.y * 6.0 * TAU) * 0.35 + caustic_phase);
	float caustic_b = sin((quv.x * -3.0 + quv.y * 5.1) * TAU
			- caustic_phase * 0.71);
	float caustic = smoothstep(1.50, 1.84, caustic_a + caustic_b);
	caustic *= smoothstep(0.05, 0.24, depth)
			* (1.0 - smoothstep(0.80, 1.0, depth));
	col = mix(col, spring_glow_color.rgb, caustic * caustic_strength);

	float source_glow = 1.0 - smoothstep(0.0, 0.18, main_distance);
	col = mix(col, spring_glow_color.rgb, source_glow * 0.20);

	float shore_shadow = 1.0 - step(
			(shore_shadow_px + px_size) / size_px.y, quv.y);
	col = mix(col, bank_shadow_color.rgb, shore_shadow * 0.66);
	float shore_cell_w = 36.0;
	float shore_cell = floor(px.x / shore_cell_w);
	float shore_local = mod(px.x, shore_cell_w);
	float shore_active = step(
			1.0 - shore_glow_density, hash21(vec2(shore_cell, 211.0)));
	float shore_pulse = floor((0.5 + 0.5 * sin(
			t / 9.2 * TAU + hash21(vec2(shore_cell, 307.0)) * TAU))
			* 3.0 + 0.5) / 3.0;
	float shore_segment = shore_active * step(shore_local, shore_cell_w * 0.38);
	float shore_row = (1.0 - step(px_size * 1.5, px.y)) * shore_segment;
	col = mix(
			col,
			spring_glow_color.rgb,
			shore_row * shore_pulse * shore_glow_strength);

	col = floor(clamp(col, vec3(0.0), vec3(1.0)) * 31.0 + 0.5) / 31.0;
	COLOR = vec4(col, 1.0);
}
