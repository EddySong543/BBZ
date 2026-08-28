shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene8 open water. Per-column topology drives shoreline, bank distance and
// depth; a shared anisotropic field drives both these ripples and the aurora
// reflection. Ice is generated as sparse shore-attached lenses, never boxes.

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

group_uniforms attached_shore_ice;
uniform float thin_ice_depth : hint_range(0.0, 0.10, 0.005) = 0.040;
uniform float thin_ice_presence : hint_range(0.0, 0.60, 0.01) = 0.38;
uniform float shore_ice_reach : hint_range(0.05, 0.30, 0.005) = 0.135;
uniform float ice_lens_spacing_cells : hint_range(24.0, 72.0, 1.0) = 42.0;
uniform vec4 ice_color : source_color = vec4(0.23, 0.41, 0.52, 1.0);
uniform float shore_ice_opacity : hint_range(0.0, 1.0, 0.01) = 0.56;
uniform float shore_ice_front_strength : hint_range(0.0, 1.0, 0.01) = 0.28;
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


float shore_ice_mask(vec2 cell, float shore_distance, float depth) {
	float spacing = max(ice_lens_spacing_cells, 1.0);
	float lens_id = floor(cell.x / spacing);
	float active_seed = scene8_hash21(vec2(lens_id + 101.0, 307.0));
	float lens_active = step(1.0 - thin_ice_presence, active_seed);
	float center_offset = mix(
			0.32, 0.68,
			scene8_hash21(vec2(lens_id + 127.0, 331.0)));
	float lens_center = (lens_id + center_offset) * spacing;
	float half_width = spacing * mix(
			0.18, 0.32,
			scene8_hash21(vec2(lens_id + 149.0, 353.0)));
	float normalized_x = abs(cell.x - lens_center) / max(half_width, 1.0);
	float lens_profile = sqrt(max(1.0 - normalized_x * normalized_x, 0.0));
	lens_profile = pow(lens_profile, 1.35);

	float rough_group = floor(cell.x / 3.0);
	float edge_roughness = (
			scene8_hash21(vec2(rough_group + 173.0, lens_id + 379.0))
			- 0.5) * 1.6 * lens_profile;
	float maximum_reach_cells = shore_ice_reach * shore_distance_cells;
	float lens_reach_cells = mix(
			2.0, maximum_reach_cells,
			scene8_hash21(vec2(lens_id + 191.0, 401.0)));
	lens_reach_cells = clamp(
			lens_reach_cells * lens_profile + edge_roughness,
			0.0, maximum_reach_cells);
	float shore_cells = shore_distance * shore_distance_cells;
	float inside_lens = 1.0 - step(1.0, normalized_x);
	float attached_to_shore = 1.0 - step(
			lens_reach_cells + 0.001, shore_cells);
	float shallow_depth_guard = 1.0 - step(thin_ice_depth, depth);
	return lens_active * inside_lens * attached_to_shore
			* shallow_depth_guard;
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
	vec3 color = topology_palette(depth, cell);

	vec3 shared_wave = shared_wave_field(cell, depth, motion_time());
	float perspective_fade = mix(
			0.55, 1.0, smoothstep(0.06, 0.86, depth));
	float trough_amount = shared_wave.y * ripple_strength * 0.72;
	float glint_amount = shared_wave.x * ripple_strength * perspective_fade;
	color = mix(color, trough_color.rgb, trough_amount);
	color = mix(color, glint_color.rgb, glint_amount);

	float bank_shadow = bank_shadow_mask(shore_distance, cell);
	color = mix(color, trough_color.rgb, bank_shadow * 0.62);

	float ice_mask = shore_ice_mask(cell, shore_distance, depth);
	float next_shore_distance = min(
			shore_distance + 1.0 / max(shore_distance_cells, 1.0), 1.0);
	float next_depth = min(
			depth + 1.0 / max(pixel_grid.y * (1.0 - horizon_y), 1.0),
			1.0);
	float ice_front = max(
			ice_mask - shore_ice_mask(
					cell, next_shore_distance, next_depth),
			0.0);
	float broken_shore_front = step(
			0.34,
			scene8_hash21(vec2(floor(cell.x / 2.0) + 421.0,
					floor(cell.y) + 443.0)));
	color = mix(color, ice_color.rgb, ice_mask * shore_ice_opacity);
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

	COLOR = vec4(color, 1.0);
}
