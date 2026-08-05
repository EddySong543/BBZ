shader_type canvas_item;
render_mode unshaded;

// Shared Scene4 environment grade. Every art layer owns a separate
// ShaderMaterial instance so Eddy can tune depth roles directly in Inspector
// without changing the authored PNG or its transform.
uniform float brightness : hint_range(0.2, 1.2, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.4, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.3, 0.01) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float highlight_rolloff : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 haze_color : source_color = vec4(0.25, 0.40, 0.33, 1.0);
uniform float haze_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform vec4 palette_shadow : source_color = vec4(0.03, 0.12, 0.11, 1.0);
uniform vec4 palette_mid : source_color = vec4(0.11, 0.27, 0.25, 1.0);
uniform vec4 palette_light : source_color = vec4(0.32, 0.48, 0.42, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float palette_source_dark : hint_range(0.0, 0.5, 0.01) = 0.04;
uniform float palette_source_light : hint_range(0.1, 1.0, 0.01) = 0.58;
// Optional source-pixel sway for hanging leaves and vines. Zero strength is
// the exact legacy/static path used by every other Scene4 layer.
uniform float sway_strength_px : hint_range(0.0, 6.0, 0.1) = 0.0;
uniform float sway_speed : hint_range(0.0, 2.0, 0.01) = 0.72;
uniform float sway_phase : hint_range(0.0, 6.3, 0.01) = 0.0;
uniform float sway_y_start : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float sway_y_end : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float sway_x_min : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float sway_x_max : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float sway_secondary_ratio : hint_range(0.1, 1.2, 0.01) = 0.57;
uniform float sway_secondary_strength : hint_range(0.0, 0.8, 0.01) = 0.36;
uniform float sway_depth_influence : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float sway_blend_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float alpha_cleanup_threshold : hint_range(0.0, 0.8, 0.01) = 0.0;
uniform float alpha_cleanup_softness : hint_range(0.01, 0.4, 0.01) = 0.18;
// Optional rectangular reveal used by the FarForest branch occluder.
uniform bool alpha_window_enabled = false;
uniform vec2 alpha_window_min = vec2(0.0);
uniform vec2 alpha_window_max = vec2(1.0);

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	float y_gate = smoothstep(
			sway_y_start,
			min(sway_y_start + 0.10, sway_y_end),
			UV.y);
	y_gate *= 1.0 - smoothstep(
			max(sway_y_end - 0.08, sway_y_start),
			sway_y_end,
			UV.y);
	float x_gate = smoothstep(sway_x_min, sway_x_min + 0.05, UV.x)
			* (1.0 - smoothstep(sway_x_max - 0.05, sway_x_max, UV.x));
	float hanging_depth = clamp(
			(UV.y - sway_y_start) / max(sway_y_end - sway_y_start, 0.001),
			0.0,
			1.0);
	float sway_wave = sin(TIME * sway_speed + sway_phase);
	sway_wave += sin(
			TIME * sway_speed * sway_secondary_ratio
			+ sway_phase * 1.31) * sway_secondary_strength;
	float sway_weight = mix(
			1.0,
			hanging_depth,
			sway_depth_influence);
	float displacement_px = sway_wave * sway_strength_px
			* sway_weight * y_gate * x_gate;
	// Blend only between the two neighbouring source pixels. This removes the
	// old 6 fps stepping while retaining crisp vertical pixel rows.
	vec2 source_pixel = UV * source_size - vec2(displacement_px, 0.0);
	vec2 base_pixel = floor(source_pixel);
	float smooth_blend_x = smoothstep(0.12, 0.88, fract(source_pixel.x));
	float snapped_blend_x = step(0.5, fract(source_pixel.x));
	float blend_x = mix(
			snapped_blend_x,
			smooth_blend_x,
			sway_blend_strength);
	vec2 sample_uv_a = (
			base_pixel + vec2(0.5, 0.5)
	) / max(source_size, vec2(1.0));
	vec2 sample_uv_b = (
			base_pixel + vec2(1.5, 0.5)
	) / max(source_size, vec2(1.0));
	vec4 source = texture(TEXTURE, UV);
	if (sway_strength_px > 0.001) {
		source = mix(
				texture(TEXTURE, sample_uv_a),
				texture(TEXTURE, sample_uv_b),
				blend_x);
	}
	vec3 color = source.rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));

	color = mix(vec3(luma), color, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;
	color = mix(color, color * tint_color.rgb, tint_strength);
	color /= vec3(1.0) + max(color, vec3(0.0)) * highlight_rolloff;

	float graded_luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 haze_target = haze_color.rgb * (0.55 + graded_luma * 0.45);
	color = mix(color, haze_target, haze_strength);

	// Remap the remaining authored olive/yellow-green into a Scene4-only
	// blue-green ink palette while preserving each source pixel's value steps.
	// Separate material instances keep foreground and distant layers tunable
	// without touching Eddy's authored transforms.
	graded_luma = dot(color, vec3(0.299, 0.587, 0.114));
	float palette_value = clamp(
			(graded_luma - palette_source_dark)
			/ max(palette_source_light - palette_source_dark, 0.001),
			0.0,
			1.0);
	vec3 mapped_palette = mix(
			palette_shadow.rgb,
			palette_mid.rgb,
			smoothstep(0.0, 0.58, palette_value));
	mapped_palette = mix(
			mapped_palette,
			palette_light.rgb,
			smoothstep(0.52, 1.0, palette_value));
	color = mix(color, mapped_palette, palette_strength);

	float alpha_window = 1.0;
	if (alpha_window_enabled) {
		alpha_window = step(alpha_window_min.x, UV.x)
				* step(UV.x, alpha_window_max.x)
				* step(alpha_window_min.y, UV.y)
				* step(UV.y, alpha_window_max.y);
	}
	float clean_alpha = source.a;
	if (alpha_cleanup_threshold > 0.001) {
		clean_alpha = smoothstep(
				alpha_cleanup_threshold,
				alpha_cleanup_threshold + alpha_cleanup_softness,
				source.a);
	}
	COLOR = vec4(
			clamp(color, vec3(0.0), vec3(1.0)),
			clean_alpha * alpha_window)
			* node_modulate;
}
