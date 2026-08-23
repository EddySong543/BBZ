shader_type canvas_item;
render_mode unshaded;

// Scene7-only character grade: warm daylight from the upper oasis opening,
// jade vegetation fill in the shadows, and a four-step shallow-water bounce.
// The source sprite remains nearest-filtered and keeps its authored hue ramps.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.06;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.03;
uniform vec4 ambient_tint : source_color = vec4(0.9, 0.96, 0.91, 1.0);
uniform float ambient_tint_amount : hint_range(0.0, 0.3) = 0.0;
uniform float highlight_shoulder_start : hint_range(0.4, 0.9) = 0.68;
uniform float highlight_shoulder_strength : hint_range(0.0, 4.0) = 0.0;

uniform vec2 light_dir = vec2(0.35, -1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.08;
uniform vec4 shadow_tint : source_color = vec4(0.38, 0.55, 0.47, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.04, 1.01, 0.96, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.03;

uniform vec4 rim_color : source_color = vec4(1.0, 0.88, 0.62, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.12;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.35, 0.68, 0.55, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.05;

uniform vec4 daylight_key_color : source_color = vec4(1.0, 0.78, 0.48, 1.0);
uniform float daylight_key_amount : hint_range(0.0, 0.2, 0.005) = 0.035;
uniform vec4 water_bounce_color : source_color = vec4(0.22, 0.62, 0.52, 1.0);
uniform float water_bounce_amount : hint_range(0.0, 0.2, 0.005) = 0.04;
uniform float water_bounce_start : hint_range(0.35, 0.9) = 0.62;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 col = source.rgb;
	float alpha = source.a;
	vec2 direction = normalize(light_dir);

	float source_luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(source_luma), col, source_saturation);
	col = (col - vec3(0.5)) * source_contrast + vec3(0.5);
	col = clamp(col, vec3(0.0), vec3(1.0));
	col = mix(col, col * ambient_tint.rgb, ambient_tint_amount);

	float lit = dot(UV - vec2(0.5), direction);
	float light_side = smoothstep(-0.34, 0.34, lit);
	vec3 directional = mix(col * shadow_tint.rgb, col, light_side);
	col = mix(col, directional, backlight);
	col = mix(col, col * skin_warmth.rgb, warmth_amount);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float dark_protection = 1.0 - luma * 0.72;
	col += fill_color.rgb
			* fill_amount
			* (0.72 + light_side * 0.28)
			* dark_protection;
	float upper_key = 1.0 - smoothstep(0.24, 0.82, UV.y);
	col += daylight_key_color.rgb
			* daylight_key_amount
			* light_side
			* upper_key
			* dark_protection;

	float water_bounce = smoothstep(water_bounce_start, 1.0, UV.y);
	water_bounce = floor(water_bounce * 4.0 + 0.5) / 4.0;
	col += water_bounce_color.rgb
			* water_bounce_amount
			* water_bounce
			* (1.0 - luma * 0.62);

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(TEXTURE, UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	col += rim_color.rgb * rim * rim_strength;
	float peak = max(col.r, max(col.g, col.b));
	float highlight_excess = max(0.0, peak - highlight_shoulder_start);
	float shoulder_peak = peak - highlight_excess + highlight_excess
			/ (1.0 + highlight_excess * highlight_shoulder_strength);
	col *= shoulder_peak / max(peak, 0.001);

	col = mix(col, flash_color.rgb, flash_amount);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), alpha) * node_modulate;
}
