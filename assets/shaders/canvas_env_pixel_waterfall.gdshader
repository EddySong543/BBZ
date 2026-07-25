shader_type canvas_item;

// Scene2 left waterfall.
// The animation is intentionally split into mouth, flow, entry foam, staggered
// splash bursts, and slow local ripples. All masks run on the same hard pixel
// grid as the foreground river; no smooth glowing disc or global impact ring.

group_uniforms layout;
uniform vec2 size_px = vec2(720.0, 1216.0);
uniform int render_part : hint_range(0, 1) = 0;
uniform float px_size : hint_range(1.0, 8.0) = 4.0;
uniform float center_x : hint_range(0.0, 1.0) = 0.5;
uniform float top_y : hint_range(-0.25, 0.5) = 0.08;
uniform float bottom_y : hint_range(0.35, 1.1) = 0.86;
uniform float top_half_width_px : hint_range(8.0, 160.0) = 72.0;
uniform float bottom_half_width_px : hint_range(8.0, 180.0) = 118.0;
uniform float bend_px : hint_range(-80.0, 80.0) = 12.0;
uniform float edge_step_px : hint_range(4.0, 64.0) = 24.0;
uniform float edge_wobble_px : hint_range(0.0, 28.0) = 14.0;
uniform float section_height_px : hint_range(24.0, 192.0) = 96.0;
uniform float section_width_wobble_px : hint_range(0.0, 40.0) = 18.0;
uniform float section_center_wobble_px : hint_range(0.0, 32.0) = 12.0;
group_uniforms;

group_uniforms mouth_and_flow;
uniform float anim_fps : hint_range(1.0, 20.0) = 6.0;
uniform float fall_speed_px : hint_range(10.0, 320.0) = 96.0;
uniform float lane_width_px : hint_range(3.0, 24.0) = 8.0;
uniform float streak_period_px : hint_range(24.0, 160.0) = 96.0;
uniform float streak_length_px : hint_range(8.0, 120.0) = 34.0;
uniform float mouth_depth_px : hint_range(12.0, 160.0) = 72.0;
uniform float mouth_highlight_density : hint_range(0.0, 1.0) = 0.34;
uniform float cross_join_density : hint_range(0.0, 0.5) = 0.06;
uniform float flow_highlight_density : hint_range(0.0, 1.0) = 0.18;
uniform float flow_gap_strength : hint_range(0.0, 0.8) = 0.18;
uniform float edge_drop_density : hint_range(0.0, 0.5) = 0.03;
group_uniforms;

group_uniforms impact;
uniform float splash_fps : hint_range(1.0, 16.0) = 6.0;
uniform float splash_cycle_a : hint_range(5.0, 36.0) = 19.0;
uniform float splash_cycle_b : hint_range(5.0, 36.0) = 23.0;
uniform float splash_cycle_c : hint_range(5.0, 36.0) = 29.0;
uniform float splash_active_ratio : hint_range(0.2, 0.9) = 0.58;
uniform float splash_reach_px : hint_range(20.0, 260.0) = 112.0;
uniform float splash_height_px : hint_range(8.0, 140.0) = 54.0;
uniform float entry_white_height_px : hint_range(4.0, 80.0) = 34.0;
uniform float impact_mist_strength : hint_range(0.0, 1.0) = 0.12;
uniform float ripple_period_sec : hint_range(1.0, 8.0) = 5.6;
uniform float ripple_reach_px : hint_range(40.0, 320.0) = 210.0;
uniform float ripple_thickness_px : hint_range(1.0, 12.0) = 4.0;
uniform float ripple_segment_density : hint_range(0.0, 1.0) = 0.32;
uniform float ripple_shadow_strength : hint_range(0.0, 1.0) = 0.30;
group_uniforms;

group_uniforms palette;
uniform vec4 deep_color : source_color = vec4(0.24, 0.48, 0.52, 0.94);
uniform vec4 mid_color : source_color = vec4(0.44, 0.68, 0.68, 0.96);
uniform vec4 light_color : source_color = vec4(0.72, 0.86, 0.80, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.95, 0.86, 1.0);
uniform vec4 mist_color : source_color = vec4(0.72, 0.84, 0.80, 1.0);
uniform vec4 ripple_shadow_color : source_color = vec4(0.09, 0.24, 0.27, 1.0);
uniform float body_alpha : hint_range(0.0, 1.0) = 0.88;
uniform float mist_alpha : hint_range(0.0, 1.0) = 0.16;
uniform float core_width_ratio : hint_range(0.1, 0.8) = 0.34;
uniform float core_light_strength : hint_range(0.0, 0.6) = 0.20;
uniform float edge_shadow_start : hint_range(0.4, 0.95) = 0.72;
uniform float edge_shadow_strength : hint_range(0.0, 0.8) = 0.52;
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 263.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float pixel_box(vec2 p, float radius) {
	return 1.0 - step(radius, max(abs(p.x), abs(p.y)));
}


float splash_drop(
		vec2 px,
		vec2 origin,
		float phase,
		float direction,
		float reach,
		float height,
		float radius,
		float active_ratio) {
	float active = 1.0 - step(active_ratio, phase);
	float p = clamp(phase / max(active_ratio, 0.001), 0.0, 1.0);
	vec2 drop_pos = origin + vec2(
			direction * reach * p,
			-height * 4.0 * p * (1.0 - p) + p * 24.0);
	return pixel_box(px - drop_pos, radius) * active;
}


float broken_ripple(
		vec2 px,
		vec2 origin,
		float phase,
		float start_radius,
		float end_radius,
		float thickness,
		float seed) {
	vec2 delta = px - origin;
	float elliptical_distance = length(vec2(delta.x, delta.y * 4.2));
	float radius = mix(start_radius, end_radius, phase);
	float ring = 1.0 - step(thickness, abs(elliptical_distance - radius));
	float cell_x = floor(delta.x / max(px_size * 4.0, 1.0));
	float broken = step(
			1.0 - ripple_segment_density,
			hash21(vec2(cell_x + seed, floor(phase * 11.0))));
	float vertical_clip = 1.0 - step(entry_white_height_px * 1.35, abs(delta.y));
	return ring * broken * vertical_clip * (1.0 - phase) * (1.0 - phase);
}


void fragment() {
	float flow_time = floor(TIME * anim_fps) / anim_fps;
	float flow_frame = floor(TIME * anim_fps);
	float splash_frame = floor(TIME * splash_fps);
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;

	float fall_span = max(bottom_y - top_y, 0.001);
	float fy = clamp((quv.y - top_y) / fall_span, 0.0, 1.0);
	float end_center = center_x + bend_px / size_px.x;
	float local_top_y = top_y;
	float local_bottom_y = bottom_y;
	float in_height = step(local_top_y, quv.y) * step(quv.y, local_bottom_y);

	float edge_row = floor(px.y / edge_step_px);
	float edge_noise = hash21(vec2(edge_row, 41.0)) - 0.5;
	float section_row = floor(px.y / section_height_px);
	float section_center = (
			hash21(vec2(section_row, 173.0)) - 0.5
	) * section_center_wobble_px;
	float section_width = (
			hash21(vec2(section_row, 227.0)) - 0.5
	) * section_width_wobble_px;
	float center = (
			mix(center_x, end_center, fy)
			+ (edge_noise * edge_wobble_px + section_center) / size_px.x
	);
	float half_width_px = (
			mix(top_half_width_px, bottom_half_width_px, pow(fy, 0.82))
			+ section_width
	);
	float local_x_px = (quv.x - center) * size_px.x;
	float norm_x = abs(local_x_px) / max(half_width_px, 0.001);
	float body = step(norm_x, 1.0) * in_height;

	float lane = floor((local_x_px + half_width_px) / lane_width_px);
	float lane_seed = hash21(vec2(lane, 83.0));
	float lane_seed_b = hash21(vec2(lane + 29.0, 131.0));
	float lane_center = abs(mod(local_x_px + half_width_px, lane_width_px) - lane_width_px * 0.5);
	float narrow_lane = 1.0 - step(lane_width_px * 0.34, lane_center);

	// Mouth: vertical highlights lead the eye into the fall. Horizontal joins
	// happen only on sparse rows, so the lip never reads as a continuous bar.
	float mouth_distance = (quv.y - local_top_y) * size_px.y;
	float mouth_zone = body * (1.0 - step(mouth_depth_px, mouth_distance));
	float mouth_phase = mod(
			px.y - flow_time * fall_speed_px * 0.72 + lane_seed * streak_period_px,
			streak_period_px * 0.72);
	float mouth_vertical = mouth_zone
			* narrow_lane
			* step(1.0 - mouth_highlight_density, lane_seed_b)
			* (1.0 - step(streak_length_px * 0.72, mouth_phase));
	float mouth_row = floor(
			(px.y - flow_time * fall_speed_px * 0.55)
			/ max(streak_period_px * 1.35, 1.0));
	float mouth_join_band = 1.0 - step(
			px_size * 1.15,
			mod(px.y - flow_time * fall_speed_px * 0.55, streak_period_px * 1.35));
	float rare_cross_join = mouth_zone
			* mouth_join_band
			* step(1.0 - cross_join_density, hash21(vec2(mouth_row, 211.0)))
			* step(norm_x, 0.78);
	float top_lip_cell = floor(
			(local_x_px + half_width_px) / max(px_size * 4.0, 1.0));
	float top_lip_segments = mouth_zone
			* (1.0 - step(px_size * 2.0, mouth_distance))
			* step(0.34, hash21(vec2(top_lip_cell, 251.0)))
			* step(norm_x, 0.9);

	// Flow: long downward dashes in neighboring lanes move at different phases.
	// A second, narrower pass breaks the curtain into depth bands without
	// replacing the direction with random horizontal blocks.
	float streak_phase = mod(
			px.y - flow_time * fall_speed_px + lane_seed * streak_period_px,
			streak_period_px);
	float long_streak = narrow_lane * (1.0 - step(streak_length_px, streak_phase));
	float thread_phase = mod(
			px.y - flow_time * fall_speed_px * 1.34 + lane_seed_b * streak_period_px,
			streak_period_px * 0.62);
	float white_thread = (1.0 - step(lane_width_px * 0.18, lane_center))
			* (1.0 - step(streak_length_px * 0.46, thread_phase))
			* step(1.0 - flow_highlight_density, lane_seed);
	float moving_gap = step(
			0.965,
			hash21(vec2(lane + 47.0, floor(
					(px.y - flow_time * fall_speed_px * 0.9)
					/ max(streak_period_px * 0.55, 1.0)))));
	float core_band = (1.0 - step(core_width_ratio, norm_x))
			* mix(0.72, 1.0, step(
					0.44,
					hash21(vec2(section_row, floor(lane * 0.25) + 307.0))));
	float edge_band = smoothstep(edge_shadow_start, 1.0, norm_x);

	vec3 water = deep_color.rgb;
	water = mix(water, mid_color.rgb, 0.54 + long_streak * 0.14);
	water = mix(water, light_color.rgb, core_band * core_light_strength);
	water = mix(water, light_color.rgb, long_streak * 0.28);
	water = mix(water, foam_color.rgb, white_thread * 0.54);
	water = mix(
			water,
			light_color.rgb,
			mouth_vertical * 0.62 + rare_cross_join * 0.30);
	water = mix(water, foam_color.rgb, top_lip_segments * 0.60);
	water = mix(water, deep_color.rgb, edge_band * edge_shadow_strength);

	float alpha = body * body_alpha;
	alpha *= 1.0 - moving_gap * flow_gap_strength;
	float lower_breakup = smoothstep(0.72, 0.98, fy)
			* step(0.91, hash21(vec2(lane + 19.0, flow_frame * 0.25)));
	alpha *= 1.0 - lower_breakup * 0.34;

	// Sparse droplets live just outside the stable silhouette.
	float drop_zone = step(1.0, norm_x) * step(norm_x, 1.24) * in_height;
	float drop_col = floor(px.x / (px_size * 2.0));
	float drop_row = floor((px.y - flow_time * fall_speed_px * 1.28) / (px_size * 6.0));
	float edge_drop = step(
			1.0 - edge_drop_density,
			hash21(vec2(drop_col, drop_row))) * drop_zone;
	water = mix(water, light_color.rgb, edge_drop);
	alpha = max(alpha, edge_drop * 0.58);

	vec3 body_water = water;
	float body_output_alpha = alpha;
	water = deep_color.rgb;
	alpha = 0.0;

	vec2 impact_origin = vec2(end_center * size_px.x, bottom_y * size_px.y);
	vec2 impact_delta = px - impact_origin;

	// The white entry patch grounds the falling water in the river. Broken
	// cells at its rim avoid a smooth luminous ellipse.
	float entry_distance = length(vec2(
			impact_delta.x / max(bottom_half_width_px + 34.0, 1.0),
			impact_delta.y / max(entry_white_height_px, 1.0)));
	float entry_shape = 1.0 - step(1.0, entry_distance);
	float entry_cell = hash21(
			floor(px / vec2(px_size * 3.0, px_size * 2.0))
			+ vec2(71.0, 29.0));
	float entry_core_distance = length(vec2(
			impact_delta.x / max(bottom_half_width_px * 0.62, 1.0),
			impact_delta.y / max(entry_white_height_px * 0.58, 1.0)));
	float entry_core = 1.0 - step(1.0, entry_core_distance);
	float entry_broken = entry_shape * step(0.42, entry_cell);
	float entry_white = max(entry_core * 0.78, entry_broken * 0.68);
	water = mix(water, light_color.rgb, entry_shape * 0.52);
	water = mix(water, foam_color.rgb, entry_white * 0.86);
	alpha = max(alpha, entry_shape * 0.24 + entry_white * 0.58);

	// Three prime-length cycles keep splash takeoff, apex, and landing from
	// synchronizing. Each burst owns different reach, height, and direction.
	float splash_phase_a = mod(splash_frame, splash_cycle_a) / splash_cycle_a;
	float splash_phase_b = mod(splash_frame + 5.0, splash_cycle_b) / splash_cycle_b;
	float splash_phase_c = mod(splash_frame + 11.0, splash_cycle_c) / splash_cycle_c;
	float splash_a = splash_drop(
			px, impact_origin + vec2(-18.0, -4.0), splash_phase_a,
			-1.0, splash_reach_px, splash_height_px, px_size * 1.15,
			splash_active_ratio);
	float splash_b = splash_drop(
			px, impact_origin + vec2(20.0, -2.0), splash_phase_b,
			1.0, splash_reach_px * 0.82, splash_height_px * 0.72, px_size,
			splash_active_ratio);
	float splash_c = splash_drop(
			px, impact_origin + vec2(2.0, -8.0), splash_phase_c,
			0.38, splash_reach_px * 0.56, splash_height_px * 1.08,
			px_size * 0.85, splash_active_ratio);
	float splash = max(splash_a, max(splash_b, splash_c));
	water = mix(water, foam_color.rgb, splash);
	alpha = max(alpha, splash * 0.96);

	float splash_mist_cell = step(
			0.72,
			hash21(floor(px / vec2(px_size * 3.0, px_size * 2.0))
					+ vec2(floor(splash_frame * 0.5), 149.0)));
	float splash_mist_shape = (1.0 - step(
			1.0,
			length(vec2(
					impact_delta.x / max(bottom_half_width_px + splash_reach_px * 0.5, 1.0),
					impact_delta.y / max(entry_white_height_px * 2.4, 1.0)))));
	float splash_mist = splash_mist_shape * splash_mist_cell * impact_mist_strength;
	water = mix(water, mist_color.rgb, splash_mist * 0.54);
	alpha = max(alpha, splash_mist * mist_alpha);

	// Slow, local broken ripples: bright leading edge plus a darker trailing
	// band. They live only around the waterfall entry and never span the screen.
	float ripple_phase_a = fract(TIME / ripple_period_sec);
	float ripple_phase_b = fract(TIME / ripple_period_sec + 0.39);
	vec2 ripple_origin = impact_origin + vec2(0.0, entry_white_height_px * 0.62);
	float ripple_bright = max(
			broken_ripple(
					px, ripple_origin, ripple_phase_a,
					bottom_half_width_px * 0.45, ripple_reach_px,
					ripple_thickness_px, 17.0),
			broken_ripple(
					px, ripple_origin, ripple_phase_b,
					bottom_half_width_px * 0.42, ripple_reach_px * 0.86,
					ripple_thickness_px, 53.0));
	float ripple_shadow = max(
			broken_ripple(
					px, ripple_origin + vec2(0.0, px_size),
					clamp(ripple_phase_a + 0.055, 0.0, 1.0),
					bottom_half_width_px * 0.45, ripple_reach_px,
					ripple_thickness_px * 1.15, 31.0),
			broken_ripple(
					px, ripple_origin + vec2(0.0, px_size),
					clamp(ripple_phase_b + 0.055, 0.0, 1.0),
					bottom_half_width_px * 0.42, ripple_reach_px * 0.86,
					ripple_thickness_px * 1.15, 67.0));
	water = mix(water, ripple_shadow_color.rgb, ripple_shadow * ripple_shadow_strength);
	water = mix(water, light_color.rgb, ripple_bright * 0.48);
	alpha = max(alpha, ripple_shadow * 0.32);
	alpha = max(alpha, ripple_bright * 0.46);

	if (render_part == 0) {
		COLOR = vec4(body_water, clamp(body_output_alpha, 0.0, 1.0));
	} else {
		COLOR = vec4(water, clamp(alpha, 0.0, 1.0));
	}
}
