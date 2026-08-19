shader_type canvas_item;
render_mode unshaded;

// Scene6 layered magma lake. It uses continuous pixel-phase feathering rather
// than hard TIME stepping, keeping slow motion readable without becoming water.
uniform vec2 size_px = vec2(1984.0, 400.0);
uniform float pixel_size : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float layer_depth : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float phase_seed : hint_range(0.0, 20.0, 0.1) = 0.0;

uniform vec4 deep_color : source_color = vec4(0.075, 0.008, 0.016, 1.0);
uniform vec4 body_color : source_color = vec4(0.26, 0.018, 0.022, 1.0);
uniform vec4 hot_color : source_color = vec4(0.86, 0.13, 0.025, 1.0);
uniform vec4 vein_color : source_color = vec4(1.0, 0.34, 0.055, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.66, 0.16, 1.0);
uniform vec4 crust_color : source_color = vec4(0.045, 0.006, 0.014, 1.0);

uniform float flow_speed : hint_range(0.0, 12.0, 0.25) = 2.6;
uniform float hot_coverage : hint_range(0.0, 0.5, 0.01) = 0.20;
uniform float core_coverage : hint_range(0.0, 0.2, 0.005) = 0.055;
uniform float crust_strength : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform float bubble_density : hint_range(0.0, 0.4, 0.01) = 0.14;
uniform float bubble_cycle_sec : hint_range(3.0, 12.0, 0.1) = 7.4;
uniform float surface_line_coverage : hint_range(0.0, 0.5, 0.01) = 0.21;


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 263.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float perspective_band(vec2 px, float depth) {
	float band_height = mix(13.0, 32.0, depth);
	return floor(px.y / band_height);
}


float counter_flow(float band_id) {
	return mix(-1.0, 1.0, step(0.5, hash21(vec2(band_id, 41.0))));
}


float broken_surface_line(vec2 px, float travel_px) {
	float segment = floor((px.x + travel_px * 0.35) / 48.0);
	float active = step(1.0 - surface_line_coverage, hash21(vec2(segment, 347.0)));
	float lip_jag = floor(hash21(vec2(segment, 313.0)) * 3.0) * pixel_size;
	return step(px.y - lip_jag, pixel_size * 1.2) * active;
}


float thermal_cell(vec2 cell, float time_phase) {
	float seed = hash21(cell + vec2(phase_seed, 17.0));
	return fract(time_phase + seed);
}


void fragment() {
	vec2 px = floor(UV * size_px / pixel_size) * pixel_size
			+ pixel_size * 0.5;
	vec2 quv = px / size_px;
	float depth = pow(clamp(quv.y, 0.0, 1.0), 0.82);
	float band_id = perspective_band(px, depth);
	float direction = counter_flow(band_id);

	// Continuous travel is converted to current/next source pixels. Only the
	// scalar field is feathered; the final silhouette remains on the 4 px grid.
	float travel = TIME * flow_speed * direction;
	float current_travel = floor(travel / pixel_size) * pixel_size;
	float next_travel = current_travel + sign(direction) * pixel_size;
	float motion_feather = smoothstep(0.16, 0.84, fract(abs(travel) / pixel_size));
	float band_phase = hash21(vec2(band_id, phase_seed + 73.0)) * 91.0;
	vec2 scale = vec2(
			mix(118.0, 84.0, depth),
			mix(46.0, 76.0, depth));
	vec2 field_uv_current = vec2(
			(px.x + current_travel + band_phase) / scale.x,
			px.y / scale.y);
	vec2 field_uv_next = vec2(
			(px.x + next_travel + band_phase) / scale.x,
			px.y / scale.y);
	float field_current = value_noise(field_uv_current);
	float field_next = value_noise(field_uv_next);
	float flow_field = mix(field_current, field_next, motion_feather);
	float detail = value_noise(field_uv_current * vec2(1.82, 1.47) + vec2(9.7, 4.3));
	flow_field = flow_field * 0.76 + detail * 0.24;

	vec3 magma = mix(body_color.rgb, deep_color.rgb, depth * 0.68);
	float row_tone = mix(0.88, 1.08, hash21(vec2(band_id, 97.0)));
	magma *= row_tone;
	float crust_threshold = mix(0.49, 0.43, depth);
	float crust = smoothstep(crust_threshold, crust_threshold + 0.15, flow_field);
	float hot_width = mix(0.018, 0.052, hot_coverage / 0.5);
	float vein = 1.0 - smoothstep(hot_width, hot_width + 0.035, abs(flow_field - crust_threshold));
	float core_width = mix(0.004, 0.016, core_coverage / 0.2);
	float core = 1.0 - smoothstep(core_width, core_width + 0.018, abs(flow_field - crust_threshold));
	magma = mix(magma, crust_color.rgb, crust * crust_strength);
	magma = mix(magma, hot_color.rgb, vein * min(hot_coverage * 2.0, 0.48));
	magma = mix(magma, vein_color.rgb, vein * min(hot_coverage * 0.72, 0.22));
	magma = mix(magma, core_color.rgb, core * min(core_coverage * 2.4, 0.18));

	// Sparse, staggered thermal cells. They never dominate the lake surface.
	vec2 bubble_cell_size = mix(vec2(190.0, 118.0), vec2(148.0, 102.0), depth);
	vec2 bubble_cell = floor(px / bubble_cell_size);
	vec2 bubble_local = mod(px, bubble_cell_size);
	float bubble_seed = hash21(bubble_cell + vec2(191.0 + phase_seed, 37.0));
	float bubble_active = step(1.0 - bubble_density, bubble_seed);
	float bubble_phase = thermal_cell(
			bubble_cell,
			TIME / max(bubble_cycle_sec, 0.001));
	vec2 bubble_center = vec2(
			mix(34.0, bubble_cell_size.x - 34.0, hash21(bubble_cell + vec2(11.0, 67.0))),
			mix(28.0, bubble_cell_size.y - 26.0, hash21(bubble_cell + vec2(83.0, 29.0))));
	vec2 bubble_delta = bubble_local - bubble_center;
	bubble_delta.y *= 1.45;
	float bubble_radius = mix(6.0, 17.0, smoothstep(0.0, 0.68, bubble_phase));
	float bubble_distance = length(bubble_delta);
	float bubble_ring = step(abs(bubble_distance - bubble_radius), pixel_size * 0.82);
	bubble_ring *= bubble_active * (1.0 - smoothstep(0.66, 0.92, bubble_phase));
	magma = mix(magma, vein_color.rgb, bubble_ring * 0.62);

	float surface_shadow = step(px.y, pixel_size * 3.5);
	float surface_lip = broken_surface_line(px, travel);
	magma = mix(magma, deep_color.rgb, surface_shadow * 0.72);
	magma = mix(magma, hot_color.rgb, surface_lip * 0.74);
	COLOR = vec4(clamp(magma, vec3(0.0), vec3(1.0)), 1.0);
}
