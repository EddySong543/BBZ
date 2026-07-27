shader_type canvas_item;

// Scene2 primary waterfall.
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
uniform float vertical_profile_enabled : hint_range(0.0, 1.0, 1.0) = 1.0;
uniform float left_edge_upper_px : hint_range(0.0, 360.0) = 132.0;
uniform float left_edge_middle_px : hint_range(0.0, 360.0) = 138.0;
uniform float left_edge_lower_px : hint_range(0.0, 360.0) = 120.0;
uniform float right_edge_upper_px : hint_range(360.0, 720.0) = 588.0;
uniform float right_edge_middle_px : hint_range(360.0, 720.0) = 594.0;
uniform float right_edge_lower_px : hint_range(360.0, 720.0) = 624.0;
uniform float vertical_step_one_y : hint_range(0.1, 0.8, 0.01) = 0.36;
uniform float vertical_step_two_y : hint_range(0.2, 0.95, 0.01) = 0.72;
group_uniforms;

group_uniforms mouth_and_flow;
uniform float anim_fps : hint_range(1.0, 20.0) = 6.0;
uniform float flow_cycle_frames : hint_range(4.0, 12.0) = 8.0;
uniform float fall_speed_px : hint_range(10.0, 320.0) = 96.0;
uniform float lane_width_px : hint_range(3.0, 24.0) = 8.0;
uniform float streak_period_px : hint_range(24.0, 160.0) = 96.0;
uniform float streak_length_px : hint_range(8.0, 120.0) = 34.0;
uniform float mouth_depth_px : hint_range(12.0, 160.0) = 72.0;
uniform float mouth_highlight_density : hint_range(0.0, 1.0) = 0.34;
uniform float cross_join_density : hint_range(0.0, 0.5) = 0.06;
uniform float major_streak_density : hint_range(0.0, 1.0) = 0.48;
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

group_uniforms bank_contact;
uniform float contact_shadow_width_px : hint_range(3.0, 36.0, 1.0) = 18.0;
uniform float contact_shadow_strength : hint_range(0.0, 0.8, 0.01) = 0.32;
uniform float contact_glint_density : hint_range(0.0, 0.6, 0.01) = 0.18;
uniform float contact_glint_strength : hint_range(0.0, 0.6, 0.01) = 0.24;
uniform vec4 contact_rock_color : source_color = vec4(0.08, 0.20, 0.24, 1.0);
uniform float contact_rock_mix : hint_range(0.0, 0.8, 0.01) = 0.42;
uniform float contact_notch_depth_px : hint_range(0.0, 16.0, 1.0) = 6.0;
uniform float contact_notch_density : hint_range(0.0, 0.5, 0.01) = 0.16;
group_uniforms;

group_uniforms cloud_occlusion;
uniform float cloud_cut_enabled : hint_range(0.0, 1.0, 1.0) = 1.0;
uniform float cloud_cut_center_y : hint_range(0.0, 1.0, 0.001) = 0.27;
uniform float cloud_cut_half_height_px : hint_range(6.0, 96.0, 1.0) = 42.0;
uniform float cloud_cut_cell_px : hint_range(12.0, 96.0, 3.0) = 36.0;
uniform float cloud_cut_density : hint_range(0.0, 1.0, 0.01) = 0.70;
uniform float cloud_cut_strength : hint_range(0.0, 1.0, 0.01) = 0.78;
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 263.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float pixel_box(vec2 p, float radius) {
	return 1.0 - step(radius, max(abs(p.x), abs(p.y)));
}


float pixel_rect(vec2 p, vec2 half_size) {
	return (
			1.0 - step(half_size.x, abs(p.x))
	) * (
			1.0 - step(half_size.y, abs(p.y))
	);
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
	float flow_cycle_frame = mod(
			flow_frame,
			max(flow_cycle_frames, 1.0));
	float splash_frame = floor(TIME * splash_fps);
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;

	float fall_span = max(bottom_y - top_y, 0.001);
	float fy = clamp((quv.y - top_y) / fall_span, 0.0, 1.0);
	float end_center = center_x + bend_px / size_px.x;
	float source_lip_cell = floor(
			(px.x - left_edge_upper_px) / max(px_size * 4.0, 1.0));
	float source_lip_jitter_px = (
			floor(hash21(vec2(source_lip_cell, 1301.0)) * 3.0) - 1.0
	) * px_size;
	float source_lip_horizontal = (
			step(left_edge_upper_px, px.x)
			* step(px.x, right_edge_upper_px));
	float local_top_y = top_y + (
			source_lip_jitter_px * source_lip_horizontal / size_px.y);
	float local_bottom_y = bottom_y;
	float in_height = step(local_top_y, quv.y) * step(quv.y, local_bottom_y);

	// Build the silhouette from tall sections rather than changing it every
	// short row. Each section keeps long vertical banks; only the boundary
	// between sections creates a short, deliberate pixel stair.
	float top_px = top_y * size_px.y;
	float section_row = floor(max(px.y - top_px, 0.0) / section_height_px);
	float section_start_y = top_px + section_row * section_height_px;
	float section_fy = clamp(
			(section_start_y / size_px.y - top_y) / fall_span,
			0.0,
			1.0);
	float edge_quantum = max(edge_step_px, px_size);
	float left_edge_px;
	float right_edge_px;
	float first_profile_step = clamp(vertical_step_one_y, 0.1, 0.8);
	float second_profile_step = clamp(
			vertical_step_two_y,
			first_profile_step + 0.05,
			0.95);
	if (vertical_profile_enabled > 0.5) {
		// vertical_profile_steps: professional pixel waterfalls read as long,
		// calm vertical banks. The whole fall owns only two deliberate ledges;
		// no per-row noise or ridge-following curve can saw through the outline.
		if (fy < first_profile_step) {
			left_edge_px = left_edge_upper_px;
			right_edge_px = right_edge_upper_px;
		} else if (fy < second_profile_step) {
			left_edge_px = left_edge_middle_px;
			right_edge_px = right_edge_middle_px;
		} else {
			left_edge_px = left_edge_lower_px;
			right_edge_px = right_edge_lower_px;
		}
	} else {
		float section_center_step = floor(
				hash21(vec2(section_row, 173.0)) * 3.0) - 1.0;
		float section_width_step = floor(
				hash21(vec2(section_row, 227.0)) * 3.0) - 1.0;
		float fallback_center_px = mix(
				center_x * size_px.x,
				end_center * size_px.x,
				section_fy
		) + section_center_step * section_center_wobble_px * 0.10;
		float fallback_half_width_px = max(
				mix(
						top_half_width_px,
						bottom_half_width_px,
						pow(section_fy, 0.82))
						+ section_width_step * section_width_wobble_px * 0.10,
				px_size * 2.0);
		left_edge_px = fallback_center_px - fallback_half_width_px;
		right_edge_px = fallback_center_px + fallback_half_width_px;
	}
	left_edge_px = floor(
			left_edge_px / edge_quantum + 0.5) * edge_quantum;
	right_edge_px = floor(
			right_edge_px / edge_quantum + 0.5) * edge_quantum;
	float center_px = (left_edge_px + right_edge_px) * 0.5;
	float half_width_px = max((right_edge_px - left_edge_px) * 0.5, px_size);
	float center = center_px / size_px.x;
	float local_x_px = px.x - center_px;
	float norm_x = abs(local_x_px) / max(half_width_px, 0.001);
	float body = (
			step(left_edge_px, px.x)
			* step(px.x, right_edge_px)
			* in_height
	);

	// Absolute lane coordinates keep the same water band continuous when the
	// terraced silhouette widens, narrows, or shifts at a section boundary.
	float lane = floor(px.x / lane_width_px);
	float lane_seed = hash21(vec2(lane, 83.0));
	float lane_seed_b = hash21(vec2(lane + 29.0, 131.0));
	float lane_center = abs(
			mod(px.x, lane_width_px) - lane_width_px * 0.5);
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
	// ref28_source_lip: small stepped foam cells describe water folding over
	// the rock edge without creating one perfectly straight white ruler.
	float top_lip_segments = mouth_zone
			* (1.0 - step(px_size * 3.0, mouth_distance))
			* step(0.22, hash21(vec2(top_lip_cell, 251.0)))
			* step(norm_x, 0.9);
	// A restrained travelling highlight makes the source edge visibly turn
	// over without scrolling the entire horizontal line in unison.
	float top_lip_motion_frame = floor(flow_cycle_frame * 0.5);
	float top_lip_travel = mouth_zone
			* (1.0 - step(px_size * 1.15, mouth_distance))
			* (1.0 - step(
					1.0,
					mod(top_lip_cell + 56.0 - top_lip_motion_frame, 7.0)))
			* step(norm_x, 0.92);
	float top_lip_hanging = mouth_zone
			* step(px_size * 1.0, mouth_distance)
			* (1.0 - step(px_size * 4.5, mouth_distance))
			* (1.0 - step(
					1.0,
					mod(top_lip_cell + 59.0 - top_lip_motion_frame, 9.0)))
			* step(norm_x, 0.88);
	// ref26_frame_blocks: the source highlight is redrawn as two or three
	// opaque blocks in every one of the eight states. This copies the visual
	// method of the reference without copying its tiny sprite geometry.
	float mouth_seed_a = hash21(vec2(flow_cycle_frame, 701.0));
	float mouth_seed_b = hash21(vec2(flow_cycle_frame, 733.0));
	float mouth_seed_c = hash21(vec2(flow_cycle_frame, 769.0));
	float mouth_shift_a = (
			floor(mouth_seed_a * 5.0) - 2.0
	) * px_size * 2.0;
	float mouth_shift_b = (
			floor(mouth_seed_b * 5.0) - 2.0
	) * px_size * 2.0;
	float mouth_shift_c = (
			floor(mouth_seed_c * 5.0) - 2.0
	) * px_size * 2.0;
	float mouth_block_a = mouth_zone * pixel_rect(
			vec2(local_x_px - mouth_shift_a, mouth_distance - px_size * 2.0),
			vec2(half_width_px * mix(0.36, 0.52, mouth_seed_b), px_size * 2.0));
	float mouth_block_b = mouth_zone * pixel_rect(
			vec2(local_x_px - mouth_shift_b, mouth_distance - px_size * 5.0),
			vec2(half_width_px * mix(0.26, 0.44, mouth_seed_c), px_size * 2.0));
	float mouth_block_c = mouth_zone * pixel_rect(
			vec2(local_x_px - mouth_shift_c, mouth_distance - px_size * 8.0),
			vec2(half_width_px * mix(0.16, 0.30, mouth_seed_a), px_size * 1.5)
	) * step(0.34, mouth_seed_b);
	float mouth_cap = max(mouth_block_a, max(mouth_block_b, mouth_block_c));

	// Narrow falling accents animate inside stable ref28-style vertical value
	// bands. Fixed pixel widths keep them from turning into the former large
	// rectangular tiles when the lower curtain becomes wider.
	float body_width_px = max(right_edge_px - left_edge_px, px_size * 2.0);
	float body_u = clamp((px.x - left_edge_px) / body_width_px, 0.0, 1.0);
	float ribbon_shift_a = (
			floor(hash21(vec2(flow_cycle_frame, 503.0)) * 3.0) - 1.0
	) * px_size * 2.0;
	float ribbon_shift_b = (
			floor(hash21(vec2(flow_cycle_frame, 547.0)) * 3.0) - 1.0
	) * px_size * 2.0;
	float ribbon_shift_c = (
			floor(hash21(vec2(flow_cycle_frame, 593.0)) * 3.0) - 1.0
	) * px_size * 2.0;
	float ribbon_shift_d = (
			floor(hash21(vec2(flow_cycle_frame, 617.0)) * 3.0) - 1.0
	) * px_size;
	float ribbon_shift_e = (
			floor(hash21(vec2(flow_cycle_frame, 659.0)) * 3.0) - 1.0
	) * px_size;
	float ribbon_x_a = mix(left_edge_px, right_edge_px, 0.24) + ribbon_shift_a;
	float ribbon_x_b = mix(left_edge_px, right_edge_px, 0.52) + ribbon_shift_b;
	float ribbon_x_c = mix(left_edge_px, right_edge_px, 0.78) + ribbon_shift_c;
	float ribbon_x_d = mix(left_edge_px, right_edge_px, 0.38) + ribbon_shift_d;
	float ribbon_x_e = mix(left_edge_px, right_edge_px, 0.67) + ribbon_shift_e;
	float ribbon_fall = flow_cycle_frame * px_size * 4.0;
	float ribbon_a = (
			1.0 - step(px_size, abs(px.x - ribbon_x_a))
	) * (
			1.0 - step(
					streak_length_px * 0.95,
					mod(px.y - ribbon_fall + 18.0, streak_period_px))
	);
	float ribbon_b = (
			1.0 - step(px_size * 1.5, abs(px.x - ribbon_x_b))
	) * (
			1.0 - step(
					streak_length_px * 1.30,
					mod(px.y - ribbon_fall + 82.0, streak_period_px * 1.18))
	);
	float ribbon_c = (
			1.0 - step(px_size, abs(px.x - ribbon_x_c))
	) * (
			1.0 - step(
					streak_length_px * 0.82,
					mod(px.y - ribbon_fall + 43.0, streak_period_px * 0.86))
	);
	float ribbon_d = (
			1.0 - step(px_size * 0.72, abs(px.x - ribbon_x_d))
	) * (
			1.0 - step(
					streak_length_px * 0.62,
					mod(px.y - ribbon_fall + 118.0, streak_period_px * 1.36))
	);
	float ribbon_e = (
			1.0 - step(px_size * 0.72, abs(px.x - ribbon_x_e))
	) * (
			1.0 - step(
					streak_length_px * 0.72,
					mod(px.y - ribbon_fall + 61.0, streak_period_px * 1.52))
	);
	// ref26_vertical_flow: five deliberately placed falling ribbons reproduce
	// the reference's calm solid water mass and sparse moving vertical accents.
	float long_streak = max(
			max(ribbon_a, ribbon_b),
			max(ribbon_c, max(ribbon_d, ribbon_e))) * body;
	float thread_phase = mod(
			px.y - flow_time * fall_speed_px * 1.34 + lane_seed_b * streak_period_px,
			streak_period_px * 0.62);
	float white_thread = (1.0 - step(lane_width_px * 0.18, lane_center))
			* (1.0 - step(streak_length_px * 0.46, thread_phase))
			* step(1.0 - flow_highlight_density, lane_seed);
	// ref28_body_bands: a limited four-value palette is arranged into stable
	// vertical water ribbons. The bands survive from frame to frame; animation
	// only moves a few thin highlights downward through them.
	float outer_shadow = (
			(1.0 - step(0.075, body_u))
			+ step(0.925, body_u));
	float dark_band_a = step(0.16, body_u) * step(body_u, 0.29);
	float dark_band_b = step(0.53, body_u) * step(body_u, 0.64);
	float bright_band_a = step(0.09, body_u) * step(body_u, 0.15);
	float bright_band_b = step(0.34, body_u) * step(body_u, 0.43);
	float bright_band_c = step(0.69, body_u) * step(body_u, 0.78);
	float body_shadow_plane = clamp(
			outer_shadow + dark_band_a * 0.52 + dark_band_b * 0.42,
			0.0,
			1.0);
	float body_light_plane = clamp(
			bright_band_a * 0.70
			+ bright_band_b
			+ bright_band_c * 0.76,
			0.0,
			1.0);
	float edge_band = step(edge_shadow_start, norm_x);
	float bank_distance_px = min(
			px.x - left_edge_px,
			right_edge_px - px.x);
	float bank_contact_shadow = body * (
			1.0 - step(contact_shadow_width_px, bank_distance_px));
	float bank_side = step(center_px, px.x);
	float right_middle_bank = bank_contact_shadow
			* bank_side
			* step(first_profile_step, fy)
			* (1.0 - step(second_profile_step, fy));
	// Use the unbounded quantized flow clock rather than the eight-frame
	// cycle index. Both the contact glints and the broad deep-water segments
	// keep travelling downward instead of restarting inside the visible tier.
	float bank_contact_scroll_px = flow_time * px_size * anim_fps;
	float bank_contact_row = floor(
			(px.y - bank_contact_scroll_px) / max(px_size * 9.0, 1.0));
	float bank_contact_gate = step(
			1.0 - contact_glint_density,
			hash21(vec2(
					bank_contact_row,
					mix(887.0, 929.0, bank_side))));
	float bank_contact_glint = body
			* (1.0 - step(
					px_size * 1.25,
					abs(bank_distance_px - px_size * 1.5)))
			* bank_contact_gate;
	float bank_deep_flow_phase = mod(
			px.y - bank_contact_scroll_px,
			max(px_size * 18.0, 1.0));
	float bank_deep_flow = right_middle_bank
			* (1.0 - step(px_size * 7.0, bank_deep_flow_phase));
	// Small, stable rock bites expose the authored ridge below the outermost
	// water pixels. They interlock the two silhouettes without a blur/filter.
	float contact_notch_row = floor(
			max(px.y - top_px, 0.0) / max(px_size * 4.0, 1.0));
	float contact_notch_seed = hash21(vec2(
			floor(contact_notch_row * 0.5),
			mix(1091.0, 1151.0, bank_side)));
	float contact_notch_gate = step(
			1.0 - contact_notch_density,
			contact_notch_seed);
	float contact_notch_depth = contact_notch_depth_px * mix(
			0.55,
			1.0,
			hash21(vec2(contact_notch_row, 1187.0)));
	float bank_contact_notch = body
			* (1.0 - step(contact_notch_depth, bank_distance_px))
			* contact_notch_gate;

	// Stable water mass first, then a small set of authored moving folds. This
	// keeps the body opaque and dimensional without procedural rain noise.
	vec3 water = mid_color.rgb;
	water = mix(water, deep_color.rgb, body_shadow_plane * 0.52);
	water = mix(water, light_color.rgb, body_light_plane * 0.28);
	water = mix(water, light_color.rgb, long_streak * 0.42);
	water = mix(water, foam_color.rgb, white_thread * 0.10);
	water = mix(water, deep_color.rgb, fy * 0.075);
	water = mix(
			water,
			light_color.rgb,
			mouth_vertical * 0.38 + rare_cross_join * 0.16);
	water = mix(water, foam_color.rgb, top_lip_segments * 0.78);
	water = mix(water, foam_color.rgb, top_lip_travel * 0.92);
	water = mix(water, light_color.rgb, top_lip_hanging * 0.62);
	water = mix(water, foam_color.rgb, mouth_cap * 0.55);
	water = mix(water, deep_color.rgb, edge_band * edge_shadow_strength);
	water = mix(
			water,
			deep_color.rgb,
			bank_contact_shadow * contact_shadow_strength);
	water = mix(
			water,
			contact_rock_color.rgb,
			bank_contact_shadow * contact_rock_mix);
	// The middle right contact is still a dark water band, but no longer a
	// static rectangle: a quiet mid-tone base exposes deep segments travelling
	// continuously down the fall.
	water = mix(water, mid_color.rgb, right_middle_bank * 0.24);
	water = mix(water, deep_color.rgb, bank_deep_flow * 0.62);
	water = mix(
			water,
			light_color.rgb,
			bank_contact_glint * contact_glint_strength);

	float alpha = body * body_alpha * (1.0 - bank_contact_notch);

	// ref28_mid_lip: the upper fall sits left of the lower fall. A thin,
	// broken white fold marks the water crossing the intermediate ledge and
	// visually carries it toward the right without becoming a thick platform.
	float mid_lip_y_px = (
			top_y + first_profile_step * fall_span) * size_px.y;
	float mid_lip_left_px = left_edge_middle_px - px_size * 2.0;
	float mid_lip_right_px = right_edge_middle_px + px_size * 3.0;
	float mid_lip_cell = floor(
			(px.x - mid_lip_left_px) / max(px_size * 4.0, 1.0));
	float mid_lip_jitter = (
			floor(hash21(vec2(mid_lip_cell, 1361.0)) * 3.0) - 1.0
	) * px_size;
	float mid_lip_segment = step(
			0.16,
			hash21(vec2(mid_lip_cell, 1409.0)));
	float mid_lip_base = (
			1.0 - step(
					px_size * 1.5,
					abs(px.y - mid_lip_y_px - mid_lip_jitter))
	) * step(mid_lip_left_px, px.x) * step(px.x, mid_lip_right_px)
			* mid_lip_segment;
	float mid_lip_motion_frame = floor(flow_cycle_frame * 0.5);
	float mid_lip_travel = mid_lip_base * (
			1.0 - step(
					1.0,
					mod(mid_lip_cell + 64.0 - mid_lip_motion_frame, 7.0)));
	// The first ledge reuses the source lip's construction language: each
	// active fold owns a short foam head, a wider pale turnover sheet, and a
	// narrow white core. All three share the ledge's authored jitter, so no
	// vertical stem can float below a missing horizontal pixel.
	float mid_fold_seed = hash21(vec2(mid_lip_cell, 1481.0));
	float mid_fold_shape_seed = hash21(vec2(mid_lip_cell, 1499.0));
	float mid_fold_phase = mod(
			flow_cycle_frame + floor(mid_fold_seed * 8.0),
			8.0);
	float mid_fold_growth = min(mid_fold_phase, 7.0 - mid_fold_phase);
	float mid_fold_slot = floor(
			mod(
					max(px.x - mid_lip_left_px, 0.0),
					px_size * 4.0)
			/ px_size);
	float mid_fold_head_width = 2.0 + floor(mid_fold_shape_seed * 2.0);
	float mid_fold_head_start = floor(
			hash21(vec2(mid_lip_cell, 1511.0))
			* (5.0 - mid_fold_head_width));
	float mid_fold_tail_width = 1.0 + floor(
			hash21(vec2(mid_lip_cell, 1523.0)) * 2.0);
	float mid_fold_tail_start = mid_fold_head_start + floor(
			(mid_fold_head_width - mid_fold_tail_width)
			* hash21(vec2(mid_lip_cell, 1531.0)));
	float mid_fold_gate = step(0.78, mid_fold_seed) * mid_lip_segment;
	float mid_fold_span = step(mid_lip_left_px, px.x)
			* step(px.x, mid_lip_right_px);
	float mid_fold_head_x = step(mid_fold_head_start, mid_fold_slot)
			* step(
					mid_fold_slot,
					mid_fold_head_start + mid_fold_head_width - 1.0);
	float mid_fold_tail_x = step(mid_fold_tail_start, mid_fold_slot)
			* step(
					mid_fold_slot,
					mid_fold_tail_start + mid_fold_tail_width - 1.0);
	float mid_fold_anchor_y = mid_lip_y_px + mid_lip_jitter;
	float mid_lip_fold_head = mid_fold_gate
			* mid_fold_span
			* mid_fold_head_x
			* (1.0 - step(
					px_size * 1.15,
					abs(px.y - mid_fold_anchor_y)));
	float mid_lip_fold_tail = mid_fold_gate
			* mid_fold_span
			* mid_fold_tail_x
			* step(mid_fold_anchor_y + px_size * 0.5, px.y)
			* (1.0 - step(
					mid_fold_anchor_y
							+ px_size * (mid_fold_growth + 1.5),
					px.y));
	float mid_lip_fold_core = mid_lip_fold_tail
			* (1.0 - step(
					mid_fold_anchor_y
							+ px_size * (min(mid_fold_growth, 1.0) + 1.5),
					px.y));
	// Keep the approved horizontal lip motion, but remove only the short
	// vertical cell that restarted halfway through its fall.
	float mid_lip_drop = 0.0;
	float mid_lip_left_shelf = step(
			min(left_edge_upper_px, left_edge_middle_px) - px_size,
			px.x) * step(
			px.x,
			max(left_edge_upper_px, left_edge_middle_px) + px_size);
	float mid_lip_right_shelf = step(
			min(right_edge_upper_px, right_edge_middle_px) - px_size,
			px.x) * step(
			px.x,
			max(right_edge_upper_px, right_edge_middle_px) + px_size);
	float mid_lip_rock = max(mid_lip_left_shelf, mid_lip_right_shelf)
			* step(mid_lip_y_px + px_size * 1.5, px.y)
			* (1.0 - step(mid_lip_y_px + px_size * 4.0, px.y));
	// A single opaque water row closes the right shoulder. The former broad
	// gap-fill rectangle rose above this row and read as a cyan block pasted
	// over the ridge, so the authored shelf is now the only water seam.
	float mid_lip_right_seam = mid_lip_right_shelf
			* (1.0 - step(
					px_size * 0.75,
					abs(px.y - mid_lip_y_px)));
	// The marked opening is only the two exposed screen pixels between the
	// scaled ridge edge and the water. One quantized shader column behind the
	// opaque ridge closes exactly that slit; the ridge masks its left half.
	float mid_lip_right_gap_fill = step(
			right_edge_upper_px + px_size * 3.0,
			px.x) * step(
			px.x,
			right_edge_upper_px + px_size * 5.0
	) * step(
			mid_lip_y_px - px_size * 2.0,
			px.y
	) * step(
			px.y,
			mid_lip_y_px);
	// One quantized cell at the ridge junction belongs to the vertical rock
	// face. Keep it static and rock-colored instead of letting the travelling
	// lip or the blue gap patch flash across it.
	float mid_lip_right_rock_restore = step(
			right_edge_upper_px + px_size * 3.0,
			px.x) * step(
			px.x,
			right_edge_upper_px + px_size * 6.0
	) * step(
			mid_lip_y_px,
			px.y
	) * step(
			px.y,
			mid_lip_y_px + px_size * 2.0);
	mid_lip_travel *= 1.0 - mid_lip_right_rock_restore;
	mid_lip_fold_head *= 1.0 - mid_lip_right_rock_restore;
	mid_lip_fold_tail *= 1.0 - mid_lip_right_rock_restore;
	mid_lip_fold_core *= 1.0 - mid_lip_right_rock_restore;
	float mid_lip_gap_water = mid_lip_right_gap_fill
			* (1.0 - mid_lip_right_rock_restore);
	water = mix(water, contact_rock_color.rgb, mid_lip_rock * 0.88);
	vec3 mid_lip_neighbor_blue = vec3(71.0, 140.0, 148.0) / 255.0;
	water = mix(water, mid_color.rgb, mid_lip_right_seam * 0.68);
	water = mix(water, light_color.rgb, mid_lip_base * 0.66);
	water = mix(water, foam_color.rgb, mid_lip_fold_head * 0.86);
	water = mix(water, foam_color.rgb, mid_lip_travel * 0.92);
	water = mix(water, light_color.rgb, mid_lip_fold_tail * 0.76);
	water = mix(water, foam_color.rgb, mid_lip_fold_core * 0.84);
	water = mix(water, light_color.rgb, mid_lip_drop * 0.78);
	// Apply the sampled neighboring blue last so lip highlights cannot tint
	// the repaired cells into a visibly different color.
	water = mix(water, mid_lip_neighbor_blue, mid_lip_gap_water);
	// Sampled from the immediately adjacent opaque ridge cell. Using the
	// ridge's own blue-black value keeps the repaired diagonal step from
	// reading as either pale water or a generic green contact shadow.
	vec3 mid_lip_ridge_neighbor = vec3(30.0, 59.0, 91.0) / 255.0;
	water = mix(water, mid_lip_ridge_neighbor, mid_lip_right_rock_restore);
	alpha = max(alpha, mid_lip_rock * 0.96);
	alpha = max(alpha, mid_lip_gap_water);
	alpha = max(alpha, mid_lip_right_rock_restore);
	alpha = max(alpha, mid_lip_right_seam);
	alpha = max(alpha, mid_lip_base * 0.96);
	alpha = max(alpha, mid_lip_fold_head * 0.98);
	alpha = max(alpha, mid_lip_fold_tail * 0.94);
	alpha = max(alpha, mid_lip_drop * 0.90);

	// ref28_lower_lip: the second terrain step now owns a complete fold rather
	// than silently switching silhouettes. Its base remains stable while short
	// foam glints and hanging cells travel across the edge on the water cycle.
	float lower_lip_y_px = (
			top_y + second_profile_step * fall_span) * size_px.y;
	float lower_lip_left_px = min(
			left_edge_middle_px,
			left_edge_lower_px) - px_size * 2.0;
	float lower_lip_right_px = max(
			right_edge_middle_px,
			right_edge_lower_px) + px_size * 3.0;
	float lower_lip_cell = floor(
			(px.x - lower_lip_left_px) / max(px_size * 4.0, 1.0));
	float lower_lip_jitter = (
			floor(hash21(vec2(lower_lip_cell, 1453.0)) * 2.0)
	) * px_size;
	float lower_lip_span = step(lower_lip_left_px, px.x)
			* step(px.x, lower_lip_right_px);
	float lower_lip_base = (
			1.0 - step(
					px_size * 1.65,
					abs(px.y - lower_lip_y_px - lower_lip_jitter))
	) * lower_lip_span;
	float lower_lip_motion_frame = floor(flow_cycle_frame * 0.5);
	float lower_lip_travel = lower_lip_base * (
			1.0 - step(
					1.0,
					mod(lower_lip_cell + 80.0 - lower_lip_motion_frame, 6.0)));
	float lower_lip_drop_gate = 1.0 - step(
			1.0,
			mod(lower_lip_cell + 86.0 - flow_cycle_frame, 8.0));
	float lower_lip_drop_height = px_size * (
			2.0 + mod(lower_lip_cell + flow_cycle_frame, 3.0));
	float lower_lip_drop = lower_lip_span
			* step(lower_lip_y_px + px_size, px.y)
			* (1.0 - step(
					lower_lip_y_px + px_size + lower_lip_drop_height,
					px.y))
			* lower_lip_drop_gate;
	// The lower ledge uses the same foam-head / pale-sheet / white-core stack,
	// but different seeds and timing keep the two falls from mirroring each
	// other. The existing base, travel glint, and drop cells remain intact.
	float lower_fold_seed = hash21(vec2(lower_lip_cell, 1549.0));
	float lower_fold_shape_seed = hash21(vec2(lower_lip_cell, 1567.0));
	float lower_fold_phase = mod(
			flow_cycle_frame + floor(lower_fold_seed * 8.0) + 2.0,
			8.0);
	float lower_fold_growth = min(
			lower_fold_phase,
			7.0 - lower_fold_phase);
	float lower_fold_slot = floor(
			mod(
					max(px.x - lower_lip_left_px, 0.0),
					px_size * 4.0)
			/ px_size);
	float lower_fold_head_width = 2.0 + floor(
			lower_fold_shape_seed * 2.0);
	float lower_fold_head_start = floor(
			hash21(vec2(lower_lip_cell, 1579.0))
			* (5.0 - lower_fold_head_width));
	float lower_fold_tail_width = 1.0 + floor(
			hash21(vec2(lower_lip_cell, 1597.0)) * 2.0);
	float lower_fold_tail_start = lower_fold_head_start + floor(
			(lower_fold_head_width - lower_fold_tail_width)
			* hash21(vec2(lower_lip_cell, 1601.0)));
	float lower_fold_gate = step(0.80, lower_fold_seed);
	float lower_fold_head_x = step(
			lower_fold_head_start,
			lower_fold_slot
	) * step(
			lower_fold_slot,
			lower_fold_head_start + lower_fold_head_width - 1.0);
	float lower_fold_tail_x = step(
			lower_fold_tail_start,
			lower_fold_slot
	) * step(
			lower_fold_slot,
			lower_fold_tail_start + lower_fold_tail_width - 1.0);
	float lower_fold_anchor_y = lower_lip_y_px + lower_lip_jitter;
	float lower_lip_fold_head = lower_fold_gate
			* lower_lip_span
			* lower_fold_head_x
			* (1.0 - step(
					px_size * 1.15,
					abs(px.y - lower_fold_anchor_y)));
	float lower_lip_fold_tail = lower_fold_gate
			* lower_lip_span
			* lower_fold_tail_x
			* step(lower_fold_anchor_y + px_size * 0.5, px.y)
			* (1.0 - step(
					lower_fold_anchor_y
							+ px_size * (lower_fold_growth + 1.5),
					px.y));
	float lower_lip_fold_core = lower_lip_fold_tail
			* (1.0 - step(
					lower_fold_anchor_y
							+ px_size
									* (min(lower_fold_growth, 1.0) + 1.5),
					px.y));
	// The authored lip extends slightly beyond the lower water body. Remove
	// only its outermost six-cell cluster: its base, travelling highlight,
	// and hanging cell combined into the circled flashing right angle.
	float lower_lip_outer_right_cleanup = step(
			right_edge_lower_px - px_size * 6.0,
			px.x);
	lower_lip_base *= 1.0 - lower_lip_outer_right_cleanup;
	lower_lip_travel *= 1.0 - lower_lip_outer_right_cleanup;
	lower_lip_drop *= 1.0 - lower_lip_outer_right_cleanup;
	lower_lip_fold_head *= 1.0 - lower_lip_outer_right_cleanup;
	lower_lip_fold_tail *= 1.0 - lower_lip_outer_right_cleanup;
	lower_lip_fold_core *= 1.0 - lower_lip_outer_right_cleanup;
	float lower_lip_left_shelf = step(
			min(left_edge_middle_px, left_edge_lower_px) - px_size,
			px.x) * step(
			px.x,
			max(left_edge_middle_px, left_edge_lower_px) + px_size);
	float lower_lip_right_shelf = step(
			min(right_edge_middle_px, right_edge_lower_px) - px_size,
			px.x) * step(
			px.x,
			max(right_edge_middle_px, right_edge_lower_px) + px_size);
	float lower_lip_rock = max(
			lower_lip_left_shelf,
			lower_lip_right_shelf)
			* (1.0 - step(
					px_size * 1.5,
					abs(px.y - lower_lip_y_px - px_size * 3.0)));
	water = mix(water, contact_rock_color.rgb, lower_lip_rock * 0.92);
	water = mix(water, light_color.rgb, lower_lip_base * 0.82);
	water = mix(water, foam_color.rgb, lower_lip_fold_head * 0.88);
	water = mix(water, foam_color.rgb, lower_lip_travel * 0.96);
	water = mix(water, light_color.rgb, lower_lip_drop * 0.82);
	water = mix(water, light_color.rgb, lower_lip_fold_tail * 0.78);
	water = mix(water, foam_color.rgb, lower_lip_fold_core * 0.86);
	alpha = max(alpha, lower_lip_rock * 0.96);
	alpha = max(alpha, lower_lip_base * 0.98);
	alpha = max(alpha, lower_lip_drop * 0.92);
	alpha = max(alpha, lower_lip_fold_head * 0.98);
	alpha = max(alpha, lower_lip_fold_tail * 0.94);

	// Sparse droplets live just outside the stable silhouette.
	float drop_zone = step(1.0, norm_x) * step(norm_x, 1.24) * in_height;
	float drop_col = floor(px.x / (px_size * 2.0));
	float drop_row = floor((px.y - flow_time * fall_speed_px * 1.28) / (px_size * 6.0));
	float edge_drop = step(
			1.0 - edge_drop_density,
			hash21(vec2(drop_col, drop_row))) * drop_zone;
	water = mix(water, light_color.rgb, edge_drop);
	alpha = max(alpha, edge_drop * 0.58);

	// P1-C: the existing upper cloud stays untouched. Coarse paired cells
	// interrupt only the water behind it, producing uneven passages through
	// mist instead of a single ruler-straight horizontal cut.
	float cloud_cut_center_px = cloud_cut_center_y * size_px.y;
	float cloud_cut_cluster = floor(
			px.x / max(cloud_cut_cell_px * 2.0, px_size));
	float cloud_cut_seed = hash21(vec2(cloud_cut_cluster, 977.0));
	float cloud_cut_active = step(1.0 - cloud_cut_density, cloud_cut_seed);
	float cloud_cut_jitter = (
			floor(hash21(vec2(cloud_cut_cluster, 1013.0)) * 5.0) - 2.0
	) * px_size * 2.0;
	float cloud_cut_height = cloud_cut_half_height_px * mix(
			0.62,
			1.10,
			hash21(vec2(cloud_cut_cluster, 1049.0)));
	float cloud_cut_distance = abs(
			px.y - cloud_cut_center_px - cloud_cut_jitter);
	float cloud_cut_core = (
			1.0 - step(cloud_cut_height, cloud_cut_distance)
	) * cloud_cut_active * body;
	float cloud_cut_fringe = (
			1.0 - step(
					cloud_cut_height + px_size * 4.0,
					cloud_cut_distance)
	) * (1.0 - cloud_cut_core) * cloud_cut_active * body;
	float waterfall_cloud_cut = cloud_cut_enabled * (
			cloud_cut_core + cloud_cut_fringe * 0.36);
	water = mix(water, mist_color.rgb, waterfall_cloud_cut * 0.62);
	alpha *= 1.0 - waterfall_cloud_cut * cloud_cut_strength;

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
