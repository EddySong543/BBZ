shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene8 open water. Per-column topology drives shoreline, bank distance and
// depth; a shared anisotropic field drives both these ripples and the aurora
// reflection. Far ice is a broken shore-attached skin whose edge is eroded by
// the same water field, never a separate lens or full-width shape layer.

group_uniforms layout;
uniform vec2 pixel_grid = vec2(320.0, 180.0);
uniform float horizon_y : hint_range(0.35, 0.75, 0.005) = 0.52;
group_uniforms;

group_uniforms lake_topology_data;
uniform sampler2D lake_topology : repeat_disable, filter_nearest;
uniform bool use_lake_topology = false;
uniform vec2 topology_base_origin_uv = vec2(0.0);
uniform vec2 topology_base_size_uv = vec2(1.0);
uniform vec2 topology_current_origin_uv = vec2(0.0);
uniform vec2 topology_current_size_uv = vec2(1.0);
group_uniforms;

#include "res://assets/shaders/canvas_env_scene8_shared_water_wave.gdshaderinc"

group_uniforms water_palette;
uniform vec4 far_color : source_color = vec4(0.026, 0.082, 0.18, 1.0);
uniform vec4 middle_color : source_color = vec4(0.025, 0.14, 0.27, 1.0);
uniform vec4 near_color : source_color = vec4(0.035, 0.205, 0.34, 1.0);
uniform vec4 trough_color : source_color = vec4(0.012, 0.045, 0.11, 1.0);
uniform vec4 glint_color : source_color = vec4(0.20, 0.50, 0.67, 1.0);
uniform float palette_depth_variation : hint_range(0.0, 0.05, 0.001) = 0.018;
uniform float bank_shadow_distance : hint_range(0.02, 0.25, 0.005) = 0.14;
uniform float ripple_strength : hint_range(0.0, 1.0, 0.01) = 0.30;
group_uniforms;

group_uniforms glacier_water_contact;
uniform vec4 glacier_contact_shadow_color : source_color = vec4(0.012, 0.070, 0.145, 1.0);
uniform vec4 glacier_contact_glint_color : source_color = vec4(0.26, 0.55, 0.64, 1.0);
uniform vec4 glacier_ice_color : source_color = vec4(0.25, 0.46, 0.56, 1.0);
uniform float glacier_contact_shadow_strength : hint_range(0.0, 0.8, 0.01) = 0.38;
uniform float glacier_contact_glint_strength : hint_range(0.0, 0.6, 0.01) = 0.24;
uniform float shore_ice_glacier_mix : hint_range(0.0, 1.0, 0.01) = 0.72;
group_uniforms;

group_uniforms broken_diagonal_glint;
uniform vec4 diagonal_glint_color : source_color = vec4(0.38, 0.74, 0.84, 1.0);
uniform float diagonal_glint_strength : hint_range(0.0, 0.6, 0.01) = 0.32;
uniform float diagonal_glint_start_x : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float diagonal_glint_end_x : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform vec4 diagonal_glint_centers = vec4(0.24, 0.40, 0.58, 0.75);
uniform vec4 diagonal_glint_half_widths = vec4(0.028, 0.037, 0.045, 0.038);
uniform float diagonal_glint_drift_cells : hint_range(0.0, 2.0, 0.1) = 0.8;
uniform float diagonal_glint_cycle_sec : hint_range(12.0, 40.0, 0.5) = 24.0;
group_uniforms;

group_uniforms attached_shore_ice;
uniform float thin_ice_depth : hint_range(0.0, 0.10, 0.005) = 0.040;
uniform float thin_ice_presence : hint_range(0.0, 0.60, 0.01) = 0.38;
uniform float shore_ice_reach : hint_range(0.05, 0.30, 0.005) = 0.135;
uniform float ice_segment_cells : hint_range(8.0, 32.0, 1.0) = 17.0;
uniform float shore_ice_breakup : hint_range(0.0, 0.8, 0.01) = 0.48;
uniform float shore_ice_water_inlay : hint_range(0.0, 0.8, 0.01) = 0.38;
uniform vec4 ice_color : source_color = vec4(0.23, 0.41, 0.52, 1.0);
uniform float shore_ice_opacity : hint_range(0.0, 1.0, 0.01) = 0.56;
uniform float shore_ice_front_strength : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float shore_ice_crack_strength : hint_range(0.0, 0.6, 0.01) = 0.22;
group_uniforms;

group_uniforms sparse_near_floes;
uniform float near_floe_min_depth : hint_range(0.50, 0.85, 0.01) = 0.68;
uniform float near_floe_max_depth : hint_range(0.75, 1.0, 0.01) = 0.92;
uniform float near_floe_min_shore_distance : hint_range(0.50, 1.0, 0.01) = 0.92;
uniform vec4 near_floe_a = vec4(88.0, 154.0, 6.0, 2.2);
uniform vec4 near_floe_b = vec4(235.0, 162.0, 7.0, 2.5);
uniform vec4 near_floe_color : source_color = vec4(0.18, 0.35, 0.46, 1.0);
uniform vec4 near_floe_shadow_color : source_color = vec4(0.01, 0.055, 0.12, 1.0);
uniform float near_floe_opacity : hint_range(0.0, 1.0, 0.01) = 0.50;
group_uniforms;


vec3 topology_palette(float depth, vec2 cell) {
	vec2 variation_cell = floor(cell / vec2(9.0, 3.0));
	float low_frequency_variation = (
			scene8_hash21(variation_cell + vec2(17.0, 31.0)) - 0.5)
			* palette_depth_variation;
	float ordered_variation = (ordered_dither_4x4(cell) - 0.5)
			* palette_depth_variation * 0.65;
	float local_depth = clamp(
			depth + low_frequency_variation + ordered_variation,
			0.0, 1.0);
	float far_to_middle = smoothstep(0.02, 0.60, local_depth);
	float middle_to_near = smoothstep(0.38, 0.98, local_depth);
	vec3 color = mix(far_color.rgb, middle_color.rgb, far_to_middle);
	return mix(color, near_color.rgb, middle_to_near);
}


float bank_shadow_mask(float shore_distance, vec2 cell) {
	float shore_group = floor(cell.x / 7.0);
	float irregular_edge = (
			scene8_hash21(vec2(shore_group + 61.0, 73.0)) - 0.5)
			* 0.045;
	float shadow_reach = max(
			bank_shadow_distance + irregular_edge, 0.025);
	return 1.0 - smoothstep(0.0, shadow_reach, shore_distance);
}


float glacier_contact_mask(float glacier_contact, vec2 cell) {
	float column_group = floor(cell.x / 3.0);
	float column_break = step(
		0.22,
		scene8_hash21(vec2(column_group + 79.0, 149.0)));
	float row_break = mix(
		0.72,
		1.0,
		step(0.44, scene8_hash21(vec2(
				column_group + 101.0, floor(cell.y) + 167.0))));
	return clamp(glacier_contact, 0.0, 1.0)
			* mix(0.58, 1.0, column_break) * row_break;
}


float soft_depth_segment(float depth, float center, float half_width) {
	float feather = 0.012;
	return smoothstep(
		center - half_width - feather,
		center - half_width,
		depth) * (1.0 - smoothstep(
		center + half_width,
		center + half_width + feather,
		depth));
}


float broken_diagonal_glint(
		vec2 cell,
		float depth,
		float shore_distance,
		vec3 shared_wave,
		float time_seconds) {
	float diagonal_x = mix(
		diagonal_glint_start_x,
		diagonal_glint_end_x,
		smoothstep(0.14, 0.88, depth)) * pixel_grid.x;
	float slow_phase = time_seconds * 6.2831853
		/ max(diagonal_glint_cycle_sec, 0.001);
	diagonal_x += sin(slow_phase) * diagonal_glint_drift_cells;
	float line_width = mix(0.62, 1.18, depth);
	float diagonal_line = 1.0 - smoothstep(
		line_width, line_width + 0.62, abs(cell.x - diagonal_x));
	float segments = soft_depth_segment(
		depth, diagonal_glint_centers.x, diagonal_glint_half_widths.x);
	segments += soft_depth_segment(
		depth, diagonal_glint_centers.y, diagonal_glint_half_widths.y);
	segments += soft_depth_segment(
		depth, diagonal_glint_centers.z, diagonal_glint_half_widths.z);
	segments += soft_depth_segment(
		depth, diagonal_glint_centers.w, diagonal_glint_half_widths.w);
	segments = clamp(segments, 0.0, 1.0);
	float broken_cells = step(
		0.38,
		scene8_hash21(vec2(
			floor(cell.x / 3.0) + 719.0,
			floor(cell.y / 2.0) + 733.0)));
	float water_response = mix(0.58, 1.0, shared_wave.x)
		* mix(0.82, 1.0, ordered_dither_4x4(cell));
	float pulse = 0.68 + 0.32 * sin(
		slow_phase * 0.73 + depth * 8.0);
	float open_water = smoothstep(0.18, 0.42, shore_distance);
	return diagonal_line * segments * broken_cells
		* water_response * pulse * open_water;
}


float shore_ice_mask(
		vec2 cell,
		float shore_distance,
		float depth,
		vec3 wave) {
	float segment_width = max(ice_segment_cells, 1.0);
	float segment_id = floor(cell.x / segment_width);
	float segment_position = fract(cell.x / segment_width);
	float segment_active = step(
			1.0 - thin_ice_presence,
			scene8_hash21(vec2(segment_id + 101.0, 307.0)));
	float reach_left = scene8_hash21(vec2(segment_id + 127.0, 331.0));
	float reach_right = scene8_hash21(vec2(segment_id + 128.0, 331.0));
	float reach_blend = smoothstep(0.0, 1.0, segment_position);
	float reach_seed = mix(reach_left, reach_right, reach_blend);

	float rough_group = floor(cell.x / 3.0);
	float edge_roughness = (
			scene8_hash21(vec2(rough_group + 173.0, segment_id + 379.0))
			- 0.5) * 1.25;
	float maximum_reach_cells = shore_ice_reach * shore_distance_cells;
	float reach_cells = mix(0.65, maximum_reach_cells, reach_seed);
	reach_cells = clamp(
			reach_cells + edge_roughness - wave.y * 0.75,
			0.35,
			maximum_reach_cells);
	float shore_cells = shore_distance * shore_distance_cells;
	float attached_to_shore = 1.0 - step(
			reach_cells + 0.001, shore_cells);
	float erosion_zone = smoothstep(
			0.22, 1.0, shore_cells / max(reach_cells, 0.001));
	float breakup_seed = scene8_hash21(vec2(
			floor(cell.x / 3.0) + 211.0,
			floor(shore_cells) + segment_id + 419.0));
	float breakup = step(
			breakup_seed,
			shore_ice_breakup * erosion_zone);
	float shallow_depth_guard = 1.0 - step(thin_ice_depth, depth);
	return segment_active * attached_to_shore
			* (1.0 - breakup) * shallow_depth_guard;
}


float ellipse_floe_lobe(
		vec2 cell,
		vec2 center,
		vec2 radius,
		float shear,
		float seed) {
	vec2 delta = cell - center;
	delta.x += delta.y * shear;
	vec2 normalized = delta / max(radius, vec2(0.5));
	float angle = atan(normalized.y, normalized.x);
	float sector = floor((angle + PI) / TAU * 12.0);
	float edge_jag = (scene8_hash21(vec2(sector + seed, seed + 509.0))
			- 0.5) * 0.18;
	return 1.0 - step(1.0 + edge_jag, length(normalized));
}


float irregular_floe_shape(vec2 cell, vec4 specification, float seed) {
	vec2 center = specification.xy;
	vec2 radius = specification.zw;
	float shear = mix(
			-0.28, 0.28,
			scene8_hash21(vec2(seed + 17.0, seed + 41.0)));
	float primary = ellipse_floe_lobe(
			cell, center, radius, shear, seed);
	vec2 secondary_center = center + vec2(radius.x * 0.28, -0.35);
	vec2 secondary_radius = radius * vec2(0.66, 0.82);
	float secondary = ellipse_floe_lobe(
			cell, secondary_center, secondary_radius,
			-shear * 0.72, seed + 83.0);
	return max(primary, secondary);
}


float near_floe_mask(
		vec2 local_cell,
		float shore_distance,
		float depth) {
	float depth_gate = step(near_floe_min_depth, depth)
			* (1.0 - step(near_floe_max_depth, depth));
	float shore_gate = step(near_floe_min_shore_distance, shore_distance);
	float floe_a = irregular_floe_shape(local_cell, near_floe_a, 733.0);
	float floe_b = irregular_floe_shape(local_cell, near_floe_b, 911.0);
	return max(floe_a, floe_b) * depth_gate * shore_gate;
}


float near_floe_contact(
		vec2 local_cell,
		float shore_distance,
		float depth,
		float floe_mask) {
	float lake_rows = max(pixel_grid.y * (1.0 - horizon_y), 1.0);
	float below_depth = min(depth + 1.0 / lake_rows, 1.0);
	float below_mask = near_floe_mask(
			local_cell + vec2(0.0, 1.0), shore_distance, below_depth);
	float front_edge = max(floe_mask - below_mask, 0.0);
	float broken_edge = step(
			0.30,
			scene8_hash21(vec2(floor(local_cell.x / 2.0) + 947.0,
					floor(local_cell.y) + 971.0)));
	return front_edge * broken_edge;
}


void fragment() {
	vec2 local_cell = floor(UV * pixel_grid);
	vec2 local_pixel_uv = (local_cell + 0.5) / pixel_grid;
	vec2 topology_uv = scene8_lake_topology_uv(local_pixel_uv, SCREEN_UV);
	vec2 cell = floor(topology_uv * pixel_grid);
	vec4 topology = sample_lake_topology(topology_uv, local_pixel_uv);
	if (topology.r < 0.5) {
		discard;
	}

	float depth = clamp(topology.b, 0.0, 1.0);
	float shore_distance = clamp(topology.g, 0.0, 1.0);
	float glacier_contact = clamp(topology.a, 0.0, 1.0);
	vec3 color = topology_palette(depth, cell);

	vec4 click_ripple = scene8_click_ripple(
			SCREEN_UV, depth, cell);
	vec3 shared_wave = shared_wave_field(
			cell + vec2(click_ripple.w, 0.0),
			depth, motion_time());
	float perspective_fade = mix(
			0.55, 1.0, smoothstep(0.06, 0.86, depth));
	float trough_amount = shared_wave.y * ripple_strength * 0.72;
	float glint_amount = shared_wave.x * ripple_strength * perspective_fade;
	color = mix(color, trough_color.rgb, trough_amount);
	color = mix(color, glint_color.rgb, glint_amount);

	float bank_shadow = bank_shadow_mask(shore_distance, cell);
	color = mix(color, trough_color.rgb, bank_shadow * 0.62);

	// FarGlacier contributes a measured contact field through topology.a. This
	// grounds its authored lower edge with broken wet pixels instead of adding
	// another hand-shaped shoreline layer or fading the glacier texture.
	float glacier_contact_field = glacier_contact_mask(
		glacier_contact, cell);
	float glacier_contact_edge = smoothstep(
		0.42, 0.94, glacier_contact);
	color = mix(
		color,
		glacier_contact_shadow_color.rgb,
		glacier_contact_field * glacier_contact_shadow_strength);
	float glacier_glint_break = step(
		0.48,
		scene8_hash21(vec2(
				floor(cell.x / 2.0) + 269.0,
				floor(cell.y) + 283.0)));
	float glacier_glint = glacier_contact_edge * glacier_glint_break
			* mix(0.58, 1.0, shared_wave.x);
	color = mix(
		color,
		glacier_contact_glint_color.rgb,
		glacier_glint * glacier_contact_glint_strength);

	float ice_mask = shore_ice_mask(
			cell, shore_distance, depth, shared_wave);
	float next_shore_distance = min(
			shore_distance + 1.0 / max(shore_distance_cells, 1.0), 1.0);
	float next_depth = min(
			depth + 1.0 / max(pixel_grid.y * (1.0 - horizon_y), 1.0),
			1.0);
	float ice_front = max(
			ice_mask - shore_ice_mask(
					cell, next_shore_distance, next_depth, shared_wave),
			0.0);
	float broken_shore_front = step(
			0.34,
			scene8_hash21(vec2(floor(cell.x / 2.0) + 421.0,
					floor(cell.y) + 443.0)));
	float ice_surface = mix(
			0.58, 1.0,
			ordered_dither_4x4(cell) * 0.62
					+ scene8_hash21(floor(cell / vec2(5.0, 2.0))
							+ vec2(487.0, 503.0)) * 0.38);
	float water_inlay = step(
			0.62,
			scene8_hash21(vec2(
					floor(cell.x / 4.0) + 557.0,
					floor(cell.y / 2.0) + 571.0))
					+ shared_wave.y * 0.22);
	float ice_mix = ice_mask * shore_ice_opacity * ice_surface
			* (1.0 - water_inlay * shore_ice_water_inlay);
	vec3 integrated_ice_color = mix(
		ice_color.rgb,
		glacier_ice_color.rgb,
		shore_ice_glacier_mix * smoothstep(
				0.02, 0.52, glacier_contact));
	color = mix(color, integrated_ice_color, ice_mix);
	float crack_group = floor(cell.x / 5.0);
	float crack_position = fract(cell.x / 5.0);
	float crack_center = mix(
			0.18, 0.82,
			scene8_hash21(vec2(crack_group + 601.0, 613.0)));
	float crack = ice_mask
			* step(0.72, scene8_hash21(vec2(crack_group + 631.0, 641.0)))
			* (1.0 - step(0.20, abs(crack_position - crack_center)));
	color = mix(
			color, trough_color.rgb,
			crack * shore_ice_crack_strength);
	color = mix(
			color, glint_color.rgb * 0.72,
			ice_front * broken_shore_front * shore_ice_front_strength);

	float near_ice = near_floe_mask(local_cell, shore_distance, depth);
	float near_contact = near_floe_contact(
			local_cell, shore_distance, depth, near_ice);
	color = mix(color, near_floe_color.rgb, near_ice * near_floe_opacity);
	color = mix(
			color, near_floe_shadow_color.rgb,
			near_contact * 0.72);
	float diagonal_light = broken_diagonal_glint(
			cell, depth, shore_distance, shared_wave, motion_time());
	diagonal_light *= 1.0 - clamp(ice_mask + near_ice, 0.0, 1.0);
	color = mix(
		color, diagonal_glint_color.rgb,
			diagonal_light * diagonal_glint_strength);
	float click_ripple_trough = click_ripple.x * 0.38;
	color = mix(color, trough_color.rgb, click_ripple_trough);
	float click_ripple_crest = clamp(
			click_ripple.y * 0.72 + click_ripple.z * 0.52,
			0.0, 0.86);
	color = mix(
			color,
			diagonal_glint_color.rgb,
			click_ripple_crest);

	COLOR = vec4(color, 1.0);
}
