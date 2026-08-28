shader_type canvas_item;
render_mode unshaded;

// Scene7-only character grade. Preserve the authored sprite first, then place
// warm desert daylight on the upper light-facing side and jade oasis bounce
// on the lower body. Every palette shift is luma-preserving so the character
// reads as standing in the scene instead of wearing a full-body color filter.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.03;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.01;
uniform float scene_exposure : hint_range(0.8, 1.1, 0.01) = 1.01;
uniform float highlight_compression : hint_range(0.0, 0.3, 0.01) = 0.03;

uniform vec2 light_dir = vec2(0.35, -1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.76, 0.67, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.03, 1.01, 0.97, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec4 rim_color : source_color = vec4(0.94, 0.8, 0.55, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.0;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.52, 0.68, 0.55, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec4 sun_key_color : source_color = vec4(1.0, 0.80, 0.50, 1.0);
uniform float sun_key_amount : hint_range(0.0, 0.4, 0.01) = 0.0;
uniform vec4 oasis_bounce_color : source_color = vec4(0.22, 0.68, 0.56, 1.0);
uniform float oasis_bounce_amount : hint_range(0.0, 0.4, 0.01) = 0.0;
uniform float oasis_bounce_start : hint_range(0.35, 0.9, 0.01) = 0.60;

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
	float sun_band = smoothstep(0.08, 0.36, lit);
	float shadow_luma = color_luma(col) * (1.0 - backlight * 0.22);
	vec3 shadow_target = luma_preserving_palette(
			shadow_tint.rgb,
			shadow_luma);
	col = mix(col, shadow_target, backlight * shadow_band);
	col = mix(col, col * skin_warmth.rgb, warmth_amount);

	float luma = color_luma(col);
	float dark_protection = 1.0 - luma * 0.7;
	col += fill_color.rgb
			* fill_amount
			* (0.68 + light_side * 0.20)
			* dark_protection;

	float upper_key = 1.0 - smoothstep(0.18, 0.86, UV.y);
	luma = color_luma(col);
	vec3 sun_target = luma_preserving_palette(
			sun_key_color.rgb,
			min(luma + 0.018 * dark_protection, 0.76));
	col = mix(
			col,
			sun_target,
			sun_key_amount * sun_band * (0.62 + upper_key * 0.38));

	float oasis_bounce = smoothstep(oasis_bounce_start, 0.94, UV.y);
	oasis_bounce = floor(oasis_bounce * 4.0 + 0.5) / 4.0;
	luma = color_luma(col);
	vec3 bounce_target = luma_preserving_palette(
			oasis_bounce_color.rgb,
			min(luma + 0.012 * (1.0 - luma), 0.68));
	col = mix(
			col,
			bounce_target,
			oasis_bounce_amount * oasis_bounce * (1.0 - sun_band * 0.30));

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(TEXTURE, UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	luma = color_luma(col);
	vec3 rim_target = luma_preserving_palette(
			rim_color.rgb,
			min(luma + 0.035, 0.68));
	col = mix(col, rim_target, rim * clamp(rim_strength, 0.0, 1.0));

	col = mix(col, flash_color.rgb, flash_amount);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), alpha) * node_modulate;
}
