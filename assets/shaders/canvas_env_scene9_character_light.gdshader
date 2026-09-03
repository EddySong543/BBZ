shader_type canvas_item;
render_mode unshaded;

// Scene9-only character grade. It keeps the authored character palette intact,
// then adds restrained silver-sky light and a stepped lower grass reflection.
// All palette shifts preserve luminance so skin and costume values stay legible.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.04;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.02;
uniform float scene_exposure : hint_range(0.8, 1.1, 0.01) = 1.0;
uniform float highlight_compression : hint_range(0.0, 0.3, 0.01) = 0.04;

uniform vec2 light_dir = vec2(0.28, -1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.08;
uniform vec4 shadow_tint : source_color = vec4(0.54, 0.60, 0.78, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.035, 1.01, 0.98, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.025;

uniform vec4 rim_color : source_color = vec4(0.82, 0.87, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.14;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.58, 0.64, 0.82, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.02;

uniform vec4 sky_key_color : source_color = vec4(0.88, 0.91, 1.0, 1.0);
uniform float sky_key_amount : hint_range(0.0, 0.4, 0.01) = 0.08;
uniform vec4 grass_bounce_color : source_color = vec4(0.47, 0.55, 0.76, 1.0);
uniform float grass_bounce_amount : hint_range(0.0, 0.4, 0.01) = 0.07;
uniform float grass_bounce_start : hint_range(0.35, 0.9, 0.01) = 0.62;

const vec3 LUMA_WEIGHTS = vec3(0.299, 0.587, 0.114);

varying vec4 node_modulate;


float color_luma(vec3 color) {
	return dot(color, LUMA_WEIGHTS);
}


vec3 luma_preserving_palette(vec3 palette_color, float target_luma) {
	float palette_luma = max(color_luma(palette_color), 0.001);
	vec3 palette_target = clamp(
			palette_color * target_luma / palette_luma,
			vec3(0.0),
			vec3(1.0));
	float corrected_luma = color_luma(palette_target);
	palette_target *= target_luma / max(corrected_luma, 0.001);
	return clamp(palette_target, vec3(0.0), vec3(1.0));
}


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 col = source.rgb;
	float alpha = source.a;
	vec2 direction = normalize(light_dir);
	float source_luma = color_luma(col);
	col = mix(vec3(source_luma), col, source_saturation);
	col = (col - vec3(0.5)) * source_contrast + vec3(0.5);
	col = clamp(col, vec3(0.0), vec3(1.0));
	col *= scene_exposure;
	col /= vec3(1.0) + col * highlight_compression;

	float lit = dot(UV - vec2(0.5), direction);
	float light_side = smoothstep(-0.34, 0.34, lit);
	float shadow_band = 1.0 - smoothstep(-0.32, 0.04, lit);
	float sky_band = smoothstep(0.08, 0.36, lit);
	float shadow_luma = color_luma(col) * (1.0 - backlight * 0.20);
	vec3 shadow_target = luma_preserving_palette(shadow_tint.rgb, shadow_luma);
	col = mix(col, shadow_target, backlight * shadow_band);
	col = mix(col, col * skin_warmth.rgb, warmth_amount);

	float luma = color_luma(col);
	float dark_protection = 1.0 - luma * 0.7;
	col += fill_color.rgb
			* fill_amount
			* (0.68 + light_side * 0.20)
			* dark_protection;

	float upper_key = 1.0 - smoothstep(0.16, 0.82, UV.y);
	luma = color_luma(col);
	vec3 sky_target = luma_preserving_palette(
			sky_key_color.rgb,
			min(luma + 0.015 * dark_protection, 0.76));
	col = mix(
			col,
			sky_target,
			sky_key_amount * sky_band * (0.58 + upper_key * 0.42));

	float grass_bounce = smoothstep(grass_bounce_start, 0.95, UV.y);
	grass_bounce = floor(grass_bounce * 4.0 + 0.5) / 4.0;
	luma = color_luma(col);
	vec3 grass_target = luma_preserving_palette(
			grass_bounce_color.rgb,
			min(luma + 0.01 * (1.0 - luma), 0.68));
	col = mix(
			col,
			grass_target,
			grass_bounce_amount * grass_bounce * (1.0 - sky_band * 0.28));

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(TEXTURE, UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	luma = color_luma(col);
	vec3 rim_target = luma_preserving_palette(
			rim_color.rgb,
			min(luma + 0.03, 0.70));
	col = mix(col, rim_target, rim * clamp(rim_strength, 0.0, 1.0));

	col = mix(col, flash_color.rgb, flash_amount);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), alpha) * node_modulate;
}
