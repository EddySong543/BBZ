shader_type canvas_item;
render_mode unshaded, blend_mix;

// A near horizontal magma lake. The platform and foreground assets render
// over this node, providing real occlusion without a screen-space mask.
uniform vec2 size_px = vec2(1984.0, 246.0);
uniform float pixel_size : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float crust_coverage : hint_range(0.45, 0.82, 0.01) = 0.72;
uniform float vein_coverage : hint_range(0.06, 0.20, 0.01) = 0.15;
uniform float core_coverage : hint_range(0.01, 0.08, 0.005) = 0.035;
uniform float loop_duration_sec : hint_range(8.0, 28.0, 0.5) = 16.0;
uniform float phase_override : hint_range(-1.0, 1.0, 0.01) = -1.0;
uniform float motion_feather : hint_range(0.05, 0.45, 0.01) = 0.18;
uniform float surface_step_px : hint_range(4.0, 20.0, 1.0) = 8.0;
uniform float far_feature_px : hint_range(40.0, 140.0, 2.0) = 76.0;
uniform float near_feature_px : hint_range(120.0, 300.0, 2.0) = 216.0;
uniform float molten_base_strength : hint_range(0.4, 1.0, 0.01) = 0.68;
uniform vec4 abyss_color : source_color = vec4(0.040, 0.006, 0.014, 1.0);
uniform vec4 crust_color : source_color = vec4(0.120, 0.018, 0.030, 1.0);
uniform vec4 deep_molten_color : source_color = vec4(0.240, 0.020, 0.014, 1.0);
uniform vec4 body_color : source_color = vec4(0.580, 0.065, 0.010, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.30, 0.055, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.60, 0.16, 1.0);


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x),
			smooth_local.y);
}


float layered_noise(vec2 p) {
	float low = value_noise(p);
	float middle = value_noise(p * 2.03 + vec2(11.7, 4.3));
	float fine = value_noise(p * 4.09 + vec2(3.1, 17.8));
	return low * 0.58 + middle * 0.28 + fine * 0.14;
}


void fragment() {
	// Every decision is made once per source-sized pixel cell. This matches the
	// authored 4x environment pixels and prevents smooth procedural smearing.
	vec2 pixel_cell = floor(UV * size_px / pixel_size);
	vec2 px = pixel_cell * pixel_size;

	// Stable broken horizon. The platform normally hides this boundary, while
	// gaps retain a few dark pixel steps instead of a full bright line.
	float surface_large = value_noise(vec2(px.x / 148.0, 9.7));
	float surface_small = value_noise(vec2(px.x / 63.0, 24.1));
	float surface_profile = surface_large * 0.76 + surface_small * 0.24;
	float surface_y = surface_step_px
			+ floor(surface_profile * 3.0 + 0.5) * pixel_size;
	float broken_surface_mask = step(surface_y, px.y);
	float contact_shadow = 1.0 - smoothstep(surface_y, surface_y + 26.0, px.y);

	float raw_depth = clamp(
			(px.y - surface_y) / max(size_px.y - surface_y, 1.0), 0.0, 1.0);
	// The far lanes consume more plane distance and therefore appear thinner;
	// the foreground lanes open gradually without turning into one giant stripe.
	float perspective_depth = pow(raw_depth, 0.72);
	float perspective_scale = raw_depth * raw_depth * (3.0 - 2.0 * raw_depth);
	float near_scale = mix(far_feature_px, near_feature_px, perspective_scale);

	float loop_phase = phase_override >= 0.0
			? fract(phase_override)
			: fract(TIME / max(loop_duration_sec, 0.001));

	// Plane coordinates widen toward the camera. Low x frequency and higher y
	// frequency force rafts and seams to read horizontally, not as lava falls.
	vec2 plane = vec2(px.x / near_scale, perspective_depth * 6.2);
	float warp_a = value_noise(vec2(
			px.x / mix(210.0, 340.0, perspective_depth),
			perspective_depth * 2.7) + vec2(7.4, 16.9));
	float warp_b = value_noise(vec2(
			px.x / mix(136.0, 270.0, perspective_depth),
			perspective_depth * 4.1) + vec2(23.8, 3.6));
	plane.x += (warp_a - 0.5) * mix(0.34, 0.72, perspective_depth);
	plane.y += (warp_b - 0.5) * 0.30;

	float raft_field = layered_noise(
			vec2(plane.x * 0.58, plane.y * 1.46) + vec2(5.7, 12.4));
	float raft_detail = layered_noise(
			vec2(plane.x * 0.94, plane.y * 2.28) + vec2(18.1, 4.6));
	float static_crust_topology = mix(raft_field, raft_detail, 0.24);
	// A second, mostly horizontal field closes the rafts into irregular islands.
	// It breaks long bands without introducing rectangular gates or vertical ribs.
	float raft_segment = layered_noise(
			vec2(plane.x * 1.52, plane.y * 0.68) + vec2(31.6, 8.2));
	float crust_threshold = mix(0.70, 0.52, crust_coverage);
	float crust_signed = min(
			static_crust_topology - crust_threshold,
			raft_segment - 0.41);
	// Static topology uses a hard pixel boundary. Only the heat travelling over
	// that topology is feathered in time, so the silhouette remains crisp.
	float hard_crust_mask = step(0.012, crust_signed);
	float crust_edge = (1.0 - hard_crust_mask)
			* step(-0.075, crust_signed);
	float crust_raft = hard_crust_mask;

	// Static energy determines the lake's resting palette. Shallow broken fronts
	// advance from the platform-side horizon toward the camera. The crust itself
	// never shifts, so this reads as heat travelling over a lake rather than the
	// whole texture sliding vertically or breathing in place.
	float static_heat_field = value_noise(
			vec2(plane.x * 0.72, plane.y * 1.31) + vec2(14.2, 6.8));
	float nearward_flow_phase = fract(
			perspective_depth * 1.24 + plane.x * 0.045
			+ (warp_a - 0.5) * 0.09 - loop_phase);
	float secondary_nearward_phase = fract(
			perspective_depth * 1.83 - plane.x * 0.036
			+ (warp_b - 0.5) * 0.07 - loop_phase * 2.0 + 0.37);
	float flow_triangle = 1.0 - abs(nearward_flow_phase * 2.0 - 1.0);
	float secondary_triangle = 1.0 - abs(secondary_nearward_phase * 2.0 - 1.0);
	float depthward_flow = smoothstep(
			0.74 - motion_feather * 0.12, 0.95, flow_triangle);
	float secondary_depthward_flow = smoothstep(
			0.80 - motion_feather * 0.10, 0.97, secondary_triangle);
	float flow_gate = smoothstep(0.34, 0.70, layered_noise(
			vec2(plane.x * 1.16, plane.y * 0.72) + vec2(2.6, 19.3)));
	float secondary_gate = smoothstep(0.48, 0.78, raft_detail);
	float nearward_advection = max(
			depthward_flow * flow_gate,
			secondary_depthward_flow * secondary_gate * 0.54);
	float thermal_advection = clamp(nearward_advection, 0.0, 1.0);

	// A broad, unbroken molten base distinguishes the lake from the far cliffs.
	// Its value is snapped to three authored palette bands instead of a smooth
	// gradient, matching the surrounding pixel-art assets.
	float depth_heat = mix(0.55, 0.82, perspective_depth);
	float static_base_energy = clamp(
			molten_base_strength * depth_heat
			+ (static_heat_field - 0.5) * 0.13, 0.0, 1.0);
	float palette_band = step(0.40, static_base_energy) * 0.46
			+ step(0.53, static_base_energy) * 0.54;
	vec3 molten_base = mix(deep_molten_color.rgb, body_color.rgb, palette_band);

	float seam_breaker = smoothstep(0.30, 0.68, layered_noise(
			vec2(plane.x * 1.84, plane.y * 0.54) + vec2(9.8, 27.1)));
	float seam_width = mix(0.55, 1.0, vein_coverage / 0.20);
	float hot_seam = crust_edge * mix(0.18, 1.0, seam_breaker) * seam_width;
	float moving_heat = hot_seam * mix(0.30, 1.0, thermal_advection);
	float molten_current = (1.0 - crust_raft)
			* smoothstep(0.58, 0.86, thermal_advection)
			* mix(0.24, 1.0, seam_breaker);
	float current_palette_band = step(0.36, molten_current) * 0.45
			+ step(0.72, molten_current) * 0.55;
	float seam_palette_band = step(0.16, moving_heat) * 0.42
			+ step(0.46, moving_heat) * 0.58;
	float core_seed = value_noise(
			vec2(plane.x * 2.7, plane.y * 3.4) + vec2(29.0, 5.0));
	float core_threshold = mix(0.91, 0.76, core_coverage / 0.08);
	float core_mask = step(core_threshold, core_seed)
			* step(0.72, thermal_advection)
			* step(0.42, moving_heat);

	float center_distance = abs(px.x - size_px.x * 0.5)
			/ max(size_px.x * 0.5, 1.0);
	float focus_protection = mix(0.78, 1.0,
			smoothstep(0.18, 0.80, center_distance));
	moving_heat *= focus_protection;
	core_mask *= focus_protection;

	float raft_darkness = crust_raft * mix(0.84, 0.94, perspective_depth);
	vec3 color = mix(molten_base, crust_color.rgb, raft_darkness);
	color = mix(color, hot_color.rgb,
			current_palette_band * mix(0.08, 0.18, perspective_depth));
	color = mix(color, hot_color.rgb,
			seam_palette_band * mix(0.38, 0.60, perspective_depth));
	color = mix(color, core_color.rgb, core_mask * 0.88);
	float contact_shadow_band = step(0.42, contact_shadow) * 0.24
			+ step(0.78, contact_shadow) * 0.24;
	color = mix(color, abyss_color.rgb, contact_shadow_band);

	float occluded_magma_lake = broken_surface_mask;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), occluded_magma_lake);
}
