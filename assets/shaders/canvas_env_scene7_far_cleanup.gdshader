shader_type canvas_item;
render_mode unshaded;

// Scene7 distant desert cleanup. Preserve the authored desert color and detail,
// remove only isolated texels, then add restrained value grouping and distance air.

group_uniforms cleanup;
uniform float cleanup_strength : hint_range(0.0, 1.0) = 0.76;
uniform float outlier_threshold : hint_range(0.05, 0.4) = 0.18;
uniform float neighbor_coherence : hint_range(0.02, 0.3) = 0.12;
uniform float edge_protection : hint_range(0.05, 0.4) = 0.20;
group_uniforms;

group_uniforms reconstruction;
uniform float macro_block_px : hint_range(1.0, 8.0) = 2.0;
uniform float detail_reduction : hint_range(0.0, 1.0) = 0.28;
uniform float value_levels : hint_range(3.0, 16.0) = 12.0;
uniform float quantize_strength : hint_range(0.0, 1.0) = 0.18;
uniform float ridge_strength : hint_range(0.0, 0.6) = 0.08;
group_uniforms;

group_uniforms palette;
uniform vec4 shadow_color : source_color = vec4(0.16, 0.31, 0.31, 1.0);
uniform vec4 middle_color : source_color = vec4(0.43, 0.44, 0.33, 1.0);
uniform vec4 sand_color : source_color = vec4(0.68, 0.57, 0.37, 1.0);
uniform vec4 sunlit_color : source_color = vec4(0.84, 0.70, 0.46, 1.0);
uniform vec4 atmosphere_color : source_color = vec4(0.39, 0.59, 0.58, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0) = 0.18;
uniform float atmosphere_strength : hint_range(0.0, 0.7) = 0.12;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
group_uniforms;


float color_delta(vec3 a, vec3 b) {
	vec3 delta = abs(a - b);
	return max(delta.r, max(delta.g, delta.b));
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

	// Targeted source repair remains edge-aware; it only removes true isolated dots.
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
	float alpha_gate = source.a * smoothstep(0.92, 0.995, opaque_neighbors);
	float cleanup_mix = cleanup_strength * outlier_gate
			* coherence_gate * edge_gate * alpha_gate;
	vec3 cleaned_source = mix(source.rgb, neighbor_mean, cleanup_mix);

	// Small value groups calm the noisy interior without replacing its painted RGB.
	vec2 macro_px = floor(source_px / macro_block_px) * macro_block_px
			+ vec2(macro_block_px * 0.5);
	vec2 macro_uv = clamp(
			macro_px * texel,
			texel * 0.5,
			vec2(1.0) - texel * 0.5);
	vec3 macro_rgb = (
			texture(TEXTURE, macro_uv).rgb * 2.0
			+ texture(TEXTURE, macro_uv + vec2(texel.x * macro_block_px, 0.0)).rgb
			+ texture(TEXTURE, macro_uv - vec2(texel.x * macro_block_px, 0.0)).rgb
			+ texture(TEXTURE, macro_uv + vec2(0.0, texel.y * macro_block_px)).rgb
			+ texture(TEXTURE, macro_uv - vec2(0.0, texel.y * macro_block_px)).rgb
		) / 6.0;
	float fine_luma = dot(cleaned_source, vec3(0.2126, 0.7152, 0.0722));
	float macro_luma = dot(macro_rgb, vec3(0.2126, 0.7152, 0.0722));
	float value = mix(fine_luma, macro_luma, detail_reduction);
	float quantized_value = floor(clamp(value, 0.0, 1.0) * value_levels + 0.5)
			/ value_levels;
	value = mix(value, quantized_value, quantize_strength);

	vec3 palette_color = mix(
			shadow_color.rgb,
			middle_color.rgb,
			smoothstep(0.12, 0.46, value));
	palette_color = mix(
			palette_color, sand_color.rgb, smoothstep(0.38, 0.70, value));
	palette_color = mix(
			palette_color, sunlit_color.rgb, smoothstep(0.66, 0.94, value));
	vec3 source_preserved = clamp(
			cleaned_source + vec3(value - fine_luma), vec3(0.0), vec3(1.0));
	vec3 color = mix(source_preserved, palette_color, palette_strength);
	float distance_haze = (1.0 - smoothstep(0.18, 0.78, UV.y))
			* atmosphere_strength;
	color = mix(color, atmosphere_color.rgb, distance_haze);

	// One source-pixel top rim is retained as a coherent dune-plane cue.
	float upper_alpha = texture(TEXTURE, source_uv - vec2(0.0, texel.y)).a;
	float top_ridge = max(source.a - upper_alpha, 0.0);
	color = mix(color, sunlit_color.rgb, top_ridge * ridge_strength);
	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * 63.0 + 0.5) / 63.0;
	COLOR = vec4(color, source.a * opacity);
}
