shader_type canvas_item;
render_mode unshaded;

// Scene7 distant desert integration. Preserve the authored dune drawing and
// reduce only local texture contrast as it recedes into continuous sky air.
// This deliberately avoids global palette replacement and macro pixel blocks.

group_uniforms cleanup;
uniform float cleanup_strength : hint_range(0.0, 1.0) = 0.76;
uniform float outlier_threshold : hint_range(0.05, 0.4) = 0.18;
uniform float neighbor_coherence : hint_range(0.02, 0.3) = 0.12;
uniform float edge_protection : hint_range(0.05, 0.4) = 0.20;
group_uniforms;

group_uniforms atmospheric_perspective;
uniform float local_radius_px : hint_range(1.0, 4.0) = 2.0;
uniform float far_detail_retention : hint_range(0.5, 1.0) = 0.74;
uniform float near_detail_retention : hint_range(0.7, 1.0) = 0.94;
uniform float far_saturation_retention : hint_range(0.5, 1.0) = 0.94;
uniform float near_saturation_retention : hint_range(0.7, 1.0) = 1.0;
uniform float distance_start : hint_range(0.0, 0.5) = 0.10;
uniform float distance_end : hint_range(0.4, 1.0) = 0.88;
uniform vec4 air_color : source_color = vec4(0.58, 0.78, 0.69, 1.0);
uniform float air_strength : hint_range(0.0, 0.4) = 0.06;
uniform float edge_air_strength : hint_range(0.0, 0.4) = 0.10;
uniform vec4 horizon_color : source_color = vec4(1.0, 0.72, 0.55, 1.0);
uniform float horizon_warmth : hint_range(0.0, 0.25) = 0.10;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

group_uniforms warm_desert_integration;
uniform vec4 sand_shadow_color : source_color = vec4(0.58, 0.43, 0.58, 1.0);
uniform vec4 sand_mid_color : source_color = vec4(0.86, 0.58, 0.5, 1.0);
uniform vec4 sand_highlight_color : source_color = vec4(1.0, 0.78, 0.59, 1.0);
uniform float sand_palette_strength : hint_range(0.0, 1.0) = 0.98;
uniform float sand_saturation : hint_range(0.7, 1.5, 0.01) = 1.06;
uniform float source_value_detail : hint_range(0.0, 0.5) = 0.08;
group_uniforms;


float color_delta(vec3 a, vec3 b) {
	vec3 delta = abs(a - b);
	return max(delta.r, max(delta.g, delta.b));
}


float warm_chroma_mask(vec3 color) {
	float maximum = max(color.r, max(color.g, color.b));
	float minimum = min(color.r, min(color.g, color.b));
	float saturation = (maximum - minimum) / max(maximum, 0.001);
	float warm_over_blue = color.r - color.b;
	return smoothstep(0.035, 0.16, warm_over_blue)
			* smoothstep(0.28, 0.62, saturation);
}


vec3 luma_scaled_palette(float luma, vec3 palette) {
	float palette_luma = dot(palette, vec3(0.2126, 0.7152, 0.0722));
	return palette * (luma / max(palette_luma, 0.001));
}


vec3 saturation_scaled_palette(vec3 palette, float gain) {
	float palette_luma = dot(palette, vec3(0.2126, 0.7152, 0.0722));
	return clamp(
			vec3(palette_luma) + (palette - vec3(palette_luma)) * gain,
			vec3(0.0),
			vec3(1.0));
}


vec3 sand_palette_ramp(float luma) {
	float middle_weight = smoothstep(0.08, 0.42, luma);
	float highlight_weight = smoothstep(0.38, 0.72, luma);
	vec3 low_to_mid = mix(
			sand_shadow_color.rgb, sand_mid_color.rgb, middle_weight);
	return mix(low_to_mid, sand_highlight_color.rgb, highlight_weight);
}


vec3 alpha_weighted_local_mean(
		vec4 center,
		vec4 left,
		vec4 right,
		vec4 up,
		vec4 down,
		vec4 far_left,
		vec4 far_right,
		vec4 far_up,
		vec4 far_down) {
	float alpha_total = center.a * 4.0
			+ left.a + right.a + up.a + down.a
			+ far_left.a + far_right.a + far_up.a + far_down.a;
	vec3 color_total = center.rgb * center.a * 4.0
			+ left.rgb * left.a + right.rgb * right.a
			+ up.rgb * up.a + down.rgb * down.a
			+ far_left.rgb * far_left.a + far_right.rgb * far_right.a
			+ far_up.rgb * far_up.a + far_down.rgb * far_down.a;
	return color_total / max(alpha_total, 0.001);
}


void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 source_px = floor(UV / texel) + vec2(0.5);
	vec2 source_uv = clamp(
			source_px * texel,
			texel * 0.5,
			vec2(1.0) - texel * 0.5);
	vec4 source = texture(TEXTURE, source_uv);
	vec4 left = texture(TEXTURE, source_uv - vec2(texel.x, 0.0));
	vec4 right = texture(TEXTURE, source_uv + vec2(texel.x, 0.0));
	vec4 up = texture(TEXTURE, source_uv - vec2(0.0, texel.y));
	vec4 down = texture(TEXTURE, source_uv + vec2(0.0, texel.y));

	// Remove only isolated source dots. Coherent dune edges remain protected.
	vec3 neighbor_mean = (left.rgb + right.rgb + up.rgb + down.rgb) * 0.25;
	float neighbor_spread = max(
			max(color_delta(left.rgb, neighbor_mean),
				color_delta(right.rgb, neighbor_mean)),
			max(color_delta(up.rgb, neighbor_mean),
				color_delta(down.rgb, neighbor_mean)));
	float outlier_score = color_delta(source.rgb, neighbor_mean);
	float outlier_gate = smoothstep(
			outlier_threshold * 0.72,
			outlier_threshold,
			outlier_score);
	float coherence_gate = 1.0 - smoothstep(
			neighbor_coherence,
			neighbor_coherence + 0.08,
			neighbor_spread);
	float edge_signal = max(
			color_delta(left.rgb, right.rgb),
			color_delta(up.rgb, down.rgb));
	float edge_gate = 1.0 - smoothstep(
			edge_protection,
			edge_protection + 0.12,
			edge_signal);
	float opaque_neighbors = min(min(left.a, right.a), min(up.a, down.a));
	float interior_gate = source.a * smoothstep(0.92, 0.995, opaque_neighbors);
	float cleanup_mix = cleanup_strength * outlier_gate
			* coherence_gate * edge_gate * interior_gate;
	vec3 cleaned_source = mix(source.rgb, neighbor_mean, cleanup_mix);

	// Compress fine contrast around the local dune color instead of replacing
	// source pixels with a new palette or a block average.
	vec2 radius = texel * local_radius_px;
	vec4 far_left = texture(TEXTURE, source_uv - vec2(radius.x, 0.0));
	vec4 far_right = texture(TEXTURE, source_uv + vec2(radius.x, 0.0));
	vec4 far_up = texture(TEXTURE, source_uv - vec2(0.0, radius.y));
	vec4 far_down = texture(TEXTURE, source_uv + vec2(0.0, radius.y));
	vec3 local_mean = alpha_weighted_local_mean(
			source, left, right, up, down,
			far_left, far_right, far_up, far_down);
	float distance_weight = 1.0 - smoothstep(distance_start, distance_end, UV.y);
	float structural_edge = smoothstep(0.09, 0.24, edge_signal);
	float detail_retention = mix(
			near_detail_retention,
			far_detail_retention,
			distance_weight);
	detail_retention = mix(detail_retention, 0.98, structural_edge);
	vec3 color = mix(
			local_mean,
			cleaned_source,
			mix(1.0, detail_retention, interior_gate));

	// Far dunes lose chroma and contrast continuously toward the sky. The lower
	// sand remains warmer so the desert still reads beneath the oasis banks.
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float saturation_retention = mix(
			near_saturation_retention,
			far_saturation_retention,
			distance_weight);
	color = mix(vec3(luma), color, saturation_retention);

	// Rebuild the imported gold/orange range as an authored desert ramp. The
	// source luminance chooses warm shadow, ochre sand, or pale-gold highlight;
	// source hue is deliberately excluded so rust-red pixels cannot survive.
	float warm_mask = warm_chroma_mask(cleaned_source);
	float warm_luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	// The three references contain a pale highlight band, but their readable
	// desert identity sits around the 70th-percentile chroma. Keep the measured
	// RGB anchors, then restore that chroma around the same luminance instead of
	// turning the whole layer into stronger orange/gold.
	vec3 reference_palette = saturation_scaled_palette(
			sand_palette_ramp(warm_luma), sand_saturation);
	vec3 value_detail_palette = luma_scaled_palette(
			warm_luma, reference_palette);
	vec3 sand_palette = mix(
			reference_palette, value_detail_palette, source_value_detail);
	vec3 warm_graded = mix(
			vec3(warm_luma), sand_palette, sand_palette_strength);
	color = mix(color, warm_graded, warm_mask);

	color = mix(color, air_color.rgb, distance_weight * air_strength);
	float horizon_weight = smoothstep(0.58, 0.96, UV.y);
	color = mix(
			color,
			horizon_color.rgb,
			horizon_weight * horizon_warmth * interior_gate);

	// Absorb only the one-pixel silhouette into the same air color. Alpha and
	// the authored outer contour are unchanged, preventing a sticker outline.
	float boundary = clamp(source.a - opaque_neighbors, 0.0, 1.0);
	float silhouette_air = boundary * edge_air_strength
			* mix(0.70, 1.0, distance_weight);
	color = mix(color, air_color.rgb, silhouette_air);

	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * 63.0 + 0.5) / 63.0;
	COLOR = vec4(color, source.a * opacity);
}
