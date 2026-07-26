shader_type canvas_item;

// Distant-grade treatment for Scene2's authored waterfall ridges.
// The source image supplies the silhouette, while a neutral atmospheric
// height gradient supplies almost all interior colour. Only a small amount of
// alpha-weighted, large-cell source luminance survives as broad structure.

uniform vec4 top_color : source_color = vec4(0.43, 0.56, 0.60, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.58, 0.69, 0.71, 1.0);
uniform vec4 atmosphere_color : source_color = vec4(0.61, 0.72, 0.76, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.75, 0.01) = 0.22;
uniform float structure_sample_radius_px : hint_range(1.0, 12.0, 1.0) = 4.0;
uniform float source_structure_strength : hint_range(0.0, 0.3, 0.01) = 0.14;
uniform float lower_haze_strength : hint_range(0.0, 0.75, 0.01) = 0.32;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float inner_edge_direction : hint_range(-1.0, 1.0, 1.0) = 0.0;
uniform vec4 inner_reflect_color : source_color = vec4(0.55, 0.72, 0.70, 1.0);
uniform float inner_reflect_strength : hint_range(0.0, 0.4, 0.01) = 0.0;
uniform float inner_reflect_width_px : hint_range(1.0, 8.0, 1.0) = 3.0;
uniform float inner_reflect_top : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float inner_reflect_bottom : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float inner_trim_enabled : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float inner_trim_start_y : hint_range(0.0, 0.9, 0.01) = 0.56;
uniform float inner_trim_base_px : hint_range(0.0, 32.0, 1.0) = 0.0;
uniform float inner_trim_max_px : hint_range(0.0, 80.0, 1.0) = 0.0;
uniform float inner_trim_steps : hint_range(2.0, 64.0, 1.0) = 5.0;
uniform float inner_trim_quantum_px : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform float inner_trim_lower_start : hint_range(0.35, 0.85, 0.01) = 0.52;
uniform float inner_trim_lower_extra_px : hint_range(0.0, 24.0, 1.0) = 0.0;


float natural_inner_profile(float progress) {
	// Follow the authored left ridge's rhythm instead of drawing one diagonal:
	// a restrained upper retreat, a short middle shoulder, then a broader
	// lower opening. The profile stays monotonic so it cannot grow stray spikes.
	if (progress < 0.12) {
		return mix(0.0, 0.06, progress / 0.12);
	}
	if (progress < 0.25) {
		return mix(0.06, 0.16, (progress - 0.12) / 0.13);
	}
	if (progress < 0.38) {
		return mix(0.16, 0.31, (progress - 0.25) / 0.13);
	}
	if (progress < 0.50) {
		return mix(0.31, 0.40, (progress - 0.38) / 0.12);
	}
	if (progress < 0.63) {
		return mix(0.40, 0.43, (progress - 0.50) / 0.13);
	}
	if (progress < 0.73) {
		return mix(0.43, 0.56, (progress - 0.63) / 0.10);
	}
	if (progress < 0.84) {
		return mix(0.56, 0.67, (progress - 0.73) / 0.11);
	}
	if (progress < 0.93) {
		return mix(0.67, 0.85, (progress - 0.84) / 0.09);
	}
	return mix(0.85, 1.0, (progress - 0.93) / 0.07);
}


float inner_trim_keep(vec2 sample_uv, vec2 texel_size) {
	vec2 uv_min = texel_size * 0.5;
	vec2 uv_max = vec2(1.0) - uv_min;
	vec2 clamped_uv = clamp(sample_uv, uv_min, uv_max);

	// inner_edge_step_trim: retreat only the waterfall-facing boundary in
	// source-pixel steps. The upper and outer silhouettes remain authored by
	// the texture and the operation is fully reversible.
	float trim_progress = clamp(
			(clamped_uv.y - inner_trim_start_y)
					/ max(1.0 - inner_trim_start_y, 0.001),
			0.0,
			1.0);
	float natural_progress = natural_inner_profile(trim_progress);
	float stepped_progress = floor(
			natural_progress * inner_trim_steps + 0.5
	) / max(inner_trim_steps, 1.0);
	float trim_width_px = mix(
			inner_trim_base_px,
			inner_trim_max_px,
			stepped_progress);
	// lower_bank_release: preserve the approved upper contour, then add a
	// second monotonic retreat only through the lower half. The slightly
	// accelerating curve keeps the basin broader without leaving a straight
	// diagonal cut or introducing reverse-facing spikes.
	float lower_progress = clamp(
			(trim_progress - inner_trim_lower_start)
					/ max(1.0 - inner_trim_lower_start, 0.001),
			0.0,
			1.0);
	float lower_release_px = floor(
			pow(lower_progress, 1.15) * inner_trim_lower_extra_px + 0.5);
	trim_width_px += lower_release_px;
	trim_width_px = floor(
			trim_width_px / max(inner_trim_quantum_px, 1.0) + 0.5
	) * max(inner_trim_quantum_px, 1.0);
	float source_x = floor(clamped_uv.x / texel_size.x) + 0.5;
	float trim_keep = step(trim_width_px, source_x);
	return mix(
			1.0,
			trim_keep,
			step(0.5, inner_trim_enabled));
}


void fragment() {
	vec4 silhouette_sample = texture(TEXTURE, UV);
	float silhouette_alpha = step(0.5, silhouette_sample.a)
			* inner_trim_keep(UV, TEXTURE_PIXEL_SIZE);
	vec2 source_size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
	vec2 spread_uv = vec2(structure_sample_radius_px) / source_size;
	vec2 uv_min = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 uv_max = vec2(1.0) - uv_min;

	vec4 samples[5];
	samples[0] = silhouette_sample;
	samples[1] = texture(
			TEXTURE, clamp(UV - vec2(spread_uv.x, 0.0), uv_min, uv_max));
	samples[2] = texture(
			TEXTURE, clamp(UV + vec2(spread_uv.x, 0.0), uv_min, uv_max));
	samples[3] = texture(
			TEXTURE, clamp(UV - vec2(0.0, spread_uv.y), uv_min, uv_max));
	samples[4] = texture(
			TEXTURE, clamp(UV + vec2(0.0, spread_uv.y), uv_min, uv_max));

	vec3 weighted_rgb = vec3(0.0);
	float alpha_sum = 0.0;
	for (int index = 0; index < 5; index++) {
		weighted_rgb += samples[index].rgb * samples[index].a;
		alpha_sum += samples[index].a;
	}
	vec3 averaged_rgb = weighted_rgb / max(alpha_sum, 0.001);
	float source_luma = dot(averaged_rgb, vec3(0.299, 0.587, 0.114));
	float structure = clamp((source_luma - 0.12) / 0.62, 0.0, 1.0);
	float structure_offset = (structure - 0.5) * source_structure_strength;

	float height_mix = smoothstep(0.05, 0.95, UV.y);
	vec3 ridge_color = mix(top_color.rgb, bottom_color.rgb, height_mix);
	ridge_color += vec3(structure_offset);
	ridge_color = mix(
			ridge_color,
			atmosphere_color.rgb,
			atmosphere_strength);
	float lower_haze = smoothstep(0.28, 1.0, UV.y) * lower_haze_strength;
	ridge_color = mix(ridge_color, atmosphere_color.rgb, lower_haze);

	// inner_edge_reflection: detect only the authored transparent boundary on
	// the waterfall-facing side. Two hard levels suggest wet reflected light
	// without adding blur, bloom, or a new contour.
	float direction_enabled = step(0.5, abs(inner_edge_direction));
	float direction_sign = sign(inner_edge_direction);
	vec2 near_uv = UV + vec2(
			TEXTURE_PIXEL_SIZE.x * inner_reflect_width_px * direction_sign,
			0.0);
	vec2 far_uv = UV + vec2(
			TEXTURE_PIXEL_SIZE.x * inner_reflect_width_px
					* 2.0 * direction_sign,
			0.0);
	float near_alpha = step(
			0.5,
			texture(TEXTURE, clamp(near_uv, uv_min, uv_max)).a
	) * inner_trim_keep(near_uv, TEXTURE_PIXEL_SIZE);
	float far_alpha = step(
			0.5,
			texture(TEXTURE, clamp(far_uv, uv_min, uv_max)).a
	) * inner_trim_keep(far_uv, TEXTURE_PIXEL_SIZE);
	float near_edge = silhouette_alpha * (1.0 - near_alpha);
	float far_edge = silhouette_alpha * (1.0 - far_alpha);
	float edge_level = max(near_edge, far_edge * 0.5);
	float water_side = mix(1.0 - UV.x, UV.x, step(0.0, direction_sign));
	float side_gate = smoothstep(0.34, 0.58, water_side);
	float height_gate = step(inner_reflect_top, UV.y)
			* step(UV.y, inner_reflect_bottom);
	float inner_reflection = edge_level * side_gate * height_gate
			* direction_enabled;
	ridge_color = mix(
			ridge_color,
			inner_reflect_color.rgb,
			inner_reflection * inner_reflect_strength);

	COLOR = vec4(
			clamp(ridge_color, vec3(0.0), vec3(1.0)),
			silhouette_alpha * opacity
	);
}
