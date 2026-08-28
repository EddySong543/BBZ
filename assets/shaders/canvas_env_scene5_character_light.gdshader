shader_type canvas_item;
render_mode unshaded;

// Scene5-only character grade. Keep the authored palette dominant, then add a
// restrained wheat-field key on the sun-facing contour. Lighting masks stay
// continuous so an AnimatedSprite frame cannot turn them into color flashes.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.02;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.02;
uniform float scene_exposure : hint_range(0.5, 1.1, 0.01) = 0.96;
uniform float highlight_compression : hint_range(0.0, 0.5, 0.01) = 0.08;

uniform vec2 light_dir = vec2(0.55, -1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.18;
uniform vec4 shadow_tint : source_color = vec4(0.56, 0.46, 0.44, 1.0);

uniform vec4 skin_warmth : source_color = vec4(1.02, 1.01, 0.98, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.015;

uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.58, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.18;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;

uniform vec4 fill_color : source_color = vec4(0.68, 0.62, 0.58, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.008;

uniform vec4 sun_key_color : source_color = vec4(1.0, 0.78, 0.52, 1.0);
uniform float sun_key_amount : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform vec3 sun_warm_shift = vec3(1.04, 1.01, 0.96);
uniform vec4 sky_ambient_color : source_color = vec4(0.62, 0.56, 0.58, 1.0);
uniform float sky_ambient_amount : hint_range(0.0, 0.4, 0.01) = 0.015;
uniform vec4 field_bounce_color : source_color = vec4(0.82, 0.68, 0.45, 1.0);
uniform float field_bounce_amount : hint_range(0.0, 0.3, 0.005) = 0.025;
uniform float field_bounce_start : hint_range(0.35, 0.9) = 0.62;

// One neutral bright-dark cycle per shared 0.75 s idle loop. This changes
// luminance only; it never alternates white and gold between sprite frames.
uniform float idle_light_cycle_sec : hint_range(0.2, 2.0, 0.01) = 0.75;
uniform float idle_light_amount : hint_range(0.0, 0.12, 0.005) = 0.03;
uniform float idle_light_phase : hint_range(0.0, 1.0, 0.01) = 0.0;

varying vec4 node_modulate;


vec3 luma_preserving_palette(
		vec3 palette_color,
		float target_luma) {
	float palette_luma = dot(palette_color, vec3(0.299, 0.587, 0.114));
	vec3 palette_target = palette_color
			* target_luma / max(palette_luma, 0.001);
	palette_target = clamp(palette_target, vec3(0.0), vec3(1.0));
	float corrected_luma = dot(
			palette_target,
			vec3(0.299, 0.587, 0.114));
	palette_target *= target_luma / max(corrected_luma, 0.001);
	return clamp(palette_target, vec3(0.0), vec3(1.0));
}


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 color = source.rgb;
	float alpha = source.a;
	vec2 direction = normalize(light_dir);

	float source_luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(source_luma), color, source_saturation);
	color = (color - vec3(0.5)) * source_contrast + vec3(0.5);
	color = clamp(color, vec3(0.0), vec3(1.0));
	color *= scene_exposure;
	color /= vec3(1.0) + color * highlight_compression;

	float directional_sample = dot(UV - vec2(0.5), direction);
	float shadow_band = 1.0
			- smoothstep(-0.34, 0.02, directional_sample);
	float sun_band = smoothstep(0.10, 0.38, directional_sample);
	float base_luma = dot(color, vec3(0.299, 0.587, 0.114));
	float shadow_target_luma = min(base_luma * 0.93, 0.52);
	vec3 shadow_palette_target = luma_preserving_palette(
			shadow_tint.rgb,
			shadow_target_luma);
	color = mix(
			color,
			shadow_palette_target,
			backlight * shadow_band);
	color = mix(color, color * skin_warmth.rgb, warmth_amount);

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float dark_protection = 1.0 - luma * 0.72;
	float sky_mask = (0.55 + (1.0 - luma) * 0.45)
			* shadow_band;
	color = mix(
			color,
			color * sky_ambient_color.rgb,
			sky_ambient_amount * sky_mask);
	color += fill_color.rgb
			* fill_amount
			* (0.62 + shadow_band * 0.18)
			* dark_protection;

	float upper_key = 1.0 - smoothstep(0.08, 0.9, UV.y);
	// Bright source pixels receive the orange palette but almost no luminance
	// lift. This is crucial for P1, whose authored sprite already has pale areas.
	float sun_highlight_guard = 1.0
			- smoothstep(0.38, 0.72, luma) * 0.72;
	float sun_target_luma = min(
			luma + 0.025 * dark_protection * sun_highlight_guard,
			0.66);
	vec3 source_warm_target = clamp(
			color * sun_warm_shift,
			vec3(0.0),
			vec3(1.0));
	vec3 sun_palette_target = luma_preserving_palette(
			sun_key_color.rgb,
			sun_target_luma);
	sun_palette_target = mix(
			source_warm_target,
			sun_palette_target,
			0.24);
	float sun_weight = sun_key_amount
			* sun_band
			* (0.72 + upper_key * 0.28);
	color = mix(color, sun_palette_target, sun_weight);

	float field_bounce = smoothstep(field_bounce_start, 1.0, UV.y);
	float bounce_luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 field_palette_target = luma_preserving_palette(
			field_bounce_color.rgb,
			min(bounce_luma + 0.012, 0.48));
	color = mix(
			color,
			field_palette_target,
			field_bounce_amount
					* field_bounce
					* (1.0 - sun_band * 0.35));

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(
			TEXTURE,
			UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	float rim_luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 rim_palette_target = luma_preserving_palette(
			rim_color.rgb,
			min(rim_luma + 0.04, 0.56));
	color = mix(
			color,
			rim_palette_target,
			rim * clamp(rim_strength, 0.0, 1.0));

	float idle_phase = fract(
			TIME / max(idle_light_cycle_sec, 0.001) + idle_light_phase);
	float idle_envelope = 0.5 - 0.5 * cos(idle_phase * 6.2831853);
	float idle_gain = 1.0
			+ (idle_envelope * 2.0 - 1.0) * idle_light_amount;
	color *= idle_gain;

	color = mix(color, flash_color.rgb, flash_amount);
	COLOR = vec4(
			clamp(color, vec3(0.0), vec3(1.0)),
			alpha) * node_modulate;
}
