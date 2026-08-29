shader_type canvas_item;
render_mode unshaded;

// Scene8-local polar star field. Sparse irregular islands and broad clear
// patches replace the shared evenly tiled star layer without touching Scene1.

group_uniforms distribution;
uniform vec2 logical_grid = vec2(320.0, 180.0);
uniform vec2 star_cells = vec2(96.0, 54.0);
uniform float coverage : hint_range(0.0, 0.8, 0.01) = 0.58;
uniform float cluster_scale : hint_range(0.5, 6.0, 0.05) = 2.15;
uniform float cluster_threshold : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float cluster_softness : hint_range(0.02, 0.5, 0.01) = 0.26;
uniform float clear_patch_scale : hint_range(0.5, 6.0, 0.05) = 1.35;
uniform float clear_patch_threshold : hint_range(0.0, 1.0, 0.01) = 0.43;
uniform float field_seed : hint_range(0.0, 1000.0, 0.01) = 73.41;
uniform float seed : hint_range(0.0, 1000.0, 0.01) = 348.71;
group_uniforms;

group_uniforms hierarchy;
uniform vec4 dust_color : source_color = vec4(0.44, 0.64, 0.88, 1.0);
uniform vec4 cold_color : source_color = vec4(0.72, 0.86, 1.0, 1.0);
uniform vec4 violet_color : source_color = vec4(0.71, 0.67, 1.0, 1.0);
uniform float dust_brightness : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float common_brightness : hint_range(0.0, 1.5, 0.01) = 0.52;
uniform float anchor_brightness : hint_range(0.0, 2.0, 0.01) = 0.88;
uniform float common_ratio : hint_range(0.0, 0.8, 0.01) = 0.22;
uniform float anchor_ratio : hint_range(0.0, 0.2, 0.005) = 0.05;
uniform float violet_ratio : hint_range(0.0, 0.5, 0.01) = 0.12;
group_uniforms;

group_uniforms clear_sky;
uniform float sky_bottom : hint_range(0.25, 0.85, 0.01) = 0.54;
uniform float horizon_fade : hint_range(0.02, 0.3, 0.01) = 0.16;
uniform vec2 aurora_clear_center = vec2(0.50, 0.24);
uniform vec2 aurora_clear_radius = vec2(0.50, 0.17);
uniform float aurora_exclusion_strength : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float edge_margin : hint_range(0.0, 0.3, 0.01) = 0.08;
group_uniforms;

group_uniforms motion;
uniform float twinkle_speed : hint_range(0.0, 2.0, 0.01) = 0.32;
uniform float twinkle_depth : hint_range(0.0, 0.4, 0.01) = 0.08;
uniform float diagnostic_time_sec : hint_range(-1.0, 300.0, 0.1) = -1.0;
group_uniforms;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


vec2 hash22(vec2 point) {
	float first = hash21(point);
	return fract(vec2(
			hash21(point + first),
			hash21(point + first + 1.7)));
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float fbm(vec2 point) {
	float sum = 0.0;
	float weight = 0.58;
	for (int octave = 0; octave < 3; octave++) {
		sum += value_noise(point) * weight;
		point = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80))
				* point * 2.03 + vec2(7.3, 11.7);
		weight *= 0.48;
	}
	return sum / 0.992;
}


void fragment() {
	float fx_time = diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
	vec2 logical_cell = floor(UV * logical_grid);
	vec2 pixel_uv = (logical_cell + vec2(0.5)) / logical_grid;
	vec2 source_cell = floor(pixel_uv * star_cells);
	vec2 random_offset = hash22(source_cell + vec2(seed, seed * 0.37));
	vec2 star_uv = (source_cell + random_offset) / star_cells;
	vec2 star_logical_cell = floor(star_uv * logical_grid);

	// Two unrelated low-frequency fields make both star islands and broad empty
	// sky. This avoids a uniform wallpaper even though each coarse cell has only
	// one inexpensive candidate.
	float cluster_noise = fbm(star_uv * vec2(cluster_scale, cluster_scale * 0.72)
			+ vec2(field_seed * 0.013, field_seed * 0.021));
	float cluster_mask = smoothstep(
			cluster_threshold,
			cluster_threshold + cluster_softness,
			cluster_noise);
	float clear_noise = fbm(star_uv * vec2(clear_patch_scale, clear_patch_scale * 0.81)
			+ vec2(field_seed * 0.071 + 19.3, field_seed * 0.043 + 7.1));
	float clear_patch_mask = smoothstep(
			clear_patch_threshold,
			clear_patch_threshold + 0.12,
			clear_noise);

	// Stars yield to the accepted aurora curtain instead of sitting on top of it.
	vec2 aurora_delta = (star_uv - aurora_clear_center)
			/ max(aurora_clear_radius, vec2(0.001));
	float aurora_proximity = exp(-dot(aurora_delta, aurora_delta) * 1.35);
	float aurora_visibility = 1.0
			- aurora_proximity * aurora_exclusion_strength;
	float horizon_visibility = smoothstep(
			sky_bottom,
			sky_bottom - horizon_fade,
			star_uv.y);
	float probability = coverage * cluster_mask * clear_patch_mask
			* aurora_visibility * horizon_visibility;
	float present = step(
			1.0 - probability,
			hash21(source_cell + vec2(seed * 1.7 + 3.1, 9.7)));

	float tier_random = hash21(source_cell + vec2(seed * 0.83 + 31.7, 17.9));
	float is_anchor = step(1.0 - anchor_ratio, tier_random);
	float is_common = (1.0 - is_anchor)
			* step(1.0 - anchor_ratio - common_ratio, tier_random);
	float is_dust = 1.0 - is_anchor - is_common;
	float brightness = dust_brightness * is_dust
			+ common_brightness * is_common
			+ anchor_brightness * is_anchor;

	vec2 distance_cell = logical_cell - star_logical_cell;
	float core = step(abs(distance_cell.x), 0.5)
			* step(abs(distance_cell.y), 0.5);
	// Only rare anchors receive one dim asymmetric companion pixel. There are no
	// repeated crosses and no shared apparent star size across the whole sky.
	float companion_side = hash21(source_cell + vec2(61.3, seed)) > 0.5 ? 1.0 : -1.0;
	vec2 companion_offset = vec2(companion_side, 0.0);
	float companion = step(length(distance_cell - companion_offset), 0.25)
			* is_anchor * 0.24;

	float phase = hash21(source_cell + vec2(43.1, seed * 0.29)) * 6.2831853;
	float twinkle_wave = sin(fx_time * twinkle_speed + phase) * 0.5 + 0.5;
	float twinkle = mix(1.0 - twinkle_depth, 1.0, twinkle_wave);
	float alpha = present * (core + companion) * brightness * twinkle;

	float violet = step(
			1.0 - violet_ratio,
			hash21(source_cell + vec2(71.7, seed * 0.11)));
	vec3 star_color = mix(cold_color.rgb, violet_color.rgb, violet);
	star_color = mix(dust_color.rgb, star_color, is_common + is_anchor);

	vec2 edge = smoothstep(vec2(0.0), vec2(edge_margin), pixel_uv)
			* smoothstep(vec2(0.0), vec2(edge_margin), 1.0 - pixel_uv);
	alpha *= edge.x * edge.y;
	COLOR = vec4(star_color, clamp(alpha, 0.0, 1.0));
}
