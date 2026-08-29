// Shared Scene8 lake coordinates and anisotropic pixel-wave field.
// Both the opaque water and the aurora reflection include this exact resource,
// so parallax, time, row geometry, segmentation, and lateral offsets cannot
// drift into two unrelated animations.

group_uniforms shared_surface_wave;
uniform float wave_cycle_sec : hint_range(8.0, 32.0, 0.5) = 18.0;
uniform float wave_travel_cells_per_sec : hint_range(0.0, 2.0, 0.05) = 0.65;
uniform float wave_max_offset_cells : hint_range(0.0, 2.0, 1.0) = 2.0;
uniform float far_wave_stride_cells : hint_range(1.0, 4.0, 0.25) = 1.75;
uniform float near_wave_stride_cells : hint_range(3.0, 8.0, 0.25) = 5.0;
uniform float far_wave_segment_cells : hint_range(6.0, 24.0, 1.0) = 11.0;
uniform float near_wave_segment_cells : hint_range(18.0, 48.0, 1.0) = 34.0;
uniform float wave_presence : hint_range(0.20, 0.80, 0.01) = 0.52;
uniform float shore_distance_cells : hint_range(1.0, 64.0, 1.0) = 24.0;
uniform float diagnostic_time_sec : hint_range(-1.0, 300.0, 0.1) = -1.0;
group_uniforms;

group_uniforms shared_click_ripple;
uniform sampler2D click_ripple_events : filter_nearest, repeat_disable;
uniform int click_ripple_count = 0;
uniform float click_ripple_duration_sec = 1.65;
uniform float click_ripple_far_radius_x = 0.0280;
uniform float click_ripple_near_radius_x = 0.0450;
uniform float click_ripple_vertical_compression = 0.38;
group_uniforms;


float scene8_hash21(vec2 p) {
	p = mod(p, vec2(509.0, 251.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float motion_time() {
	return diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
}


float ordered_dither_4x4(vec2 cell) {
	vec2 tile = mod(cell, 4.0);
	float value = 0.0;
	if (tile.y < 1.0) {
		value = tile.x < 1.0 ? 0.0 : (
				tile.x < 2.0 ? 8.0 : (tile.x < 3.0 ? 2.0 : 10.0));
	} else if (tile.y < 2.0) {
		value = tile.x < 1.0 ? 12.0 : (
				tile.x < 2.0 ? 4.0 : (tile.x < 3.0 ? 14.0 : 6.0));
	} else if (tile.y < 3.0) {
		value = tile.x < 1.0 ? 3.0 : (
				tile.x < 2.0 ? 11.0 : (tile.x < 3.0 ? 1.0 : 9.0));
	} else {
		value = tile.x < 1.0 ? 15.0 : (
				tile.x < 2.0 ? 7.0 : (tile.x < 3.0 ? 13.0 : 5.0));
	}
	return (value + 0.5) / 16.0;
}


vec4 scene8_single_click_ripple(
		vec2 screen_uv,
		float depth,
		vec2 cell,
		vec4 event_data) {
	if (event_data.w <= 0.0) {
		return vec4(0.0);
	}
	float normalized_age = clamp(
			event_data.z / max(click_ripple_duration_sec, 0.001),
			0.0, 1.0);
	// The first frame already owns a small readable crest, then the ripple
	// expands and fades. Every sample is snapped to the shared logical grid.
	float rise = mix(0.62, 1.0, smoothstep(0.0, 0.08, normalized_age));
	float fall = 1.0 - smoothstep(0.58, 1.0, normalized_age);
	float life = rise * fall * event_data.w;
	vec2 pixel_uv = (floor(screen_uv * pixel_grid) + 0.5) / pixel_grid;
	vec2 event_uv = (floor(event_data.xy * pixel_grid) + 0.5) / pixel_grid;
	vec2 delta = pixel_uv - event_uv;
	float maximum_radius_x = mix(
			click_ripple_far_radius_x,
			click_ripple_near_radius_x, depth);
	vec2 ellipse_radius = vec2(
			maximum_radius_x,
			maximum_radius_x * click_ripple_vertical_compression);
	float ellipse_distance = length(delta / max(ellipse_radius, vec2(0.0001)));
	float ring_radius = mix(
			0.12, 1.0, 1.0 - pow(1.0 - normalized_age, 2.0));
	float band_width = mix(0.075, 0.045, depth);
	float angle = atan(
			delta.y / max(click_ripple_vertical_compression, 0.001),
			delta.x);
	float segment_id = floor((angle + PI) / TAU * 18.0);
	float primary_breaks = step(
			0.18, scene8_hash21(vec2(segment_id + 1201.0, 1217.0)));
	float secondary_breaks = step(
			0.30, scene8_hash21(vec2(segment_id + 1237.0, 1259.0)));
	float primary_ring = (1.0 - step(
			band_width, abs(ellipse_distance - ring_radius)))
			* primary_breaks * life;
	float secondary_radius = ring_radius * 0.67;
	float secondary_ring = (1.0 - step(
			band_width * 0.88,
			abs(ellipse_distance - secondary_radius)))
			* secondary_breaks
			* smoothstep(0.12, 0.30, normalized_age) * life * 0.72;
	float inner_trough = (1.0 - step(
			band_width * 1.45,
			abs(ellipse_distance - ring_radius + band_width * 1.9)))
			* primary_breaks * life * 0.62;
	float horizontal_direction = sign(delta.x);
	float offset_cells = round(
			(primary_ring + secondary_ring)
			* mix(1.0, 2.0, depth)) * horizontal_direction;
	return vec4(
			inner_trough,
			primary_ring,
			secondary_ring,
			offset_cells);
}


vec4 scene8_click_ripple(vec2 screen_uv, float depth, vec2 cell) {
	vec4 combined = vec4(0.0);
	for (int ripple_index = 0;
			ripple_index < click_ripple_count; ripple_index++) {
		vec4 event_data = texelFetch(
				click_ripple_events, ivec2(ripple_index, 0), 0);
		vec4 response = scene8_single_click_ripple(
				screen_uv, depth, cell, event_data);
		combined = vec4(
				max(combined.x, response.x),
				max(combined.y, response.y),
				max(combined.z, response.z),
				clamp(combined.w + response.w, -3.0, 3.0));
	}
	return combined;
}


vec2 scene8_lake_topology_uv(vec2 fallback_pixel_uv, vec2 screen_uv) {
	if (!use_lake_topology) {
		return fallback_pixel_uv;
	}
	vec2 current_size = max(
			abs(topology_current_size_uv), vec2(0.000001));
	vec2 mountain_uv = (
			(screen_uv - topology_current_origin_uv) / current_size);
	return clamp(
			topology_base_origin_uv
					+ mountain_uv * topology_base_size_uv,
			vec2(0.0), vec2(1.0));
}


vec4 sample_lake_topology(
		vec2 topology_uv,
		vec2 fallback_pixel_uv) {
	if (!use_lake_topology) {
		float fallback_water = step(
				horizon_y - 2.0 / max(pixel_grid.y, 1.0),
				fallback_pixel_uv.y);
		float fallback_depth = clamp(
				(fallback_pixel_uv.y - horizon_y)
						/ max(1.0 - horizon_y, 0.001),
				0.0, 1.0);
		return vec4(
				fallback_water, fallback_depth,
				fallback_depth, 0.0);
	}
	return texture(lake_topology, topology_uv);
}


vec3 shared_wave_field(vec2 cell, float depth, float time_seconds) {
	float perspective = smoothstep(0.0, 1.0, depth);
	float row_stride = mix(
			far_wave_stride_cells, near_wave_stride_cells, perspective);
	float row_coordinate = cell.y / max(row_stride, 1.0);
	float row_id = floor(row_coordinate);
	float row_fraction = fract(row_coordinate);
	float row_seed = scene8_hash21(vec2(row_id + 19.0, 43.0));
	float direction = mix(-1.0, 1.0, step(0.5, row_seed));
	float moving_cell_x = cell.x
			+ time_seconds * wave_travel_cells_per_sec * direction;

	float bend_cells = mix(5.0, 11.0, perspective);
	float bend_id = floor(moving_cell_x / bend_cells);
	float bend = (scene8_hash21(vec2(bend_id + 71.0, row_id + 97.0))
			- 0.5) * mix(0.54, 0.34, perspective);
	float ridge_center = mix(0.22, 0.78, row_seed) + bend;
	float ridge_distance = abs(row_fraction - ridge_center) * row_stride;
	float ridge_width = mix(0.32, 0.92, perspective);
	float ridge = 1.0 - smoothstep(
			ridge_width, ridge_width + 0.34, ridge_distance);

	float segment_cells = mix(
			far_wave_segment_cells,
			near_wave_segment_cells,
			perspective);
	float segment_id = floor(moving_cell_x / segment_cells);
	float segment_seed = scene8_hash21(
			vec2(segment_id + 113.0, row_id + 151.0));
	float segment_active = step(1.0 - wave_presence, segment_seed);
	float segment_position = fract(moving_cell_x / segment_cells);
	float segment_start = mix(
			0.02, 0.18,
			scene8_hash21(vec2(segment_id + 179.0, row_id + 193.0)));
	float segment_end = mix(
			0.56, 0.94,
			scene8_hash21(vec2(segment_id + 211.0, row_id + 227.0)));
	float segment_feather = mix(0.06, 0.035, perspective);
	float segment_mask = smoothstep(
			segment_start,
			segment_start + segment_feather,
			segment_position) * (1.0 - smoothstep(
			segment_end - segment_feather,
			segment_end,
			segment_position));
	ridge *= segment_active * segment_mask;

	float trough_center = fract(ridge_center + 0.48);
	float trough_distance = abs(row_fraction - trough_center) * row_stride;
	float trough_width = mix(0.24, 0.72, perspective);
	float trough = 1.0 - smoothstep(
			trough_width, trough_width + 0.30, trough_distance);
	float trough_seed = scene8_hash21(
			vec2(segment_id + 239.0, row_id + 263.0));
	trough *= step(0.46, trough_seed) * segment_mask;

	float offset_phase = time_seconds * TAU / max(wave_cycle_sec, 0.001)
			+ row_id * 0.73 + segment_seed * TAU;
	float lateral_offset = round(clamp(
			sin(offset_phase) * wave_max_offset_cells,
			-wave_max_offset_cells,
			wave_max_offset_cells));
	return vec3(ridge, trough, lateral_offset);
}
