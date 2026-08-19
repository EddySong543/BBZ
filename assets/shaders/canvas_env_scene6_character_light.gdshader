shader_type canvas_item;
render_mode unshaded;

// Scene6 character lighting: preserve authored frame values first. The forge
// tint is a stable, low-energy grade; it must never read as a red spotlight.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.72, 0.66, 0.60, 1.0);
uniform float flash_peak_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float flash_dark_response : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.0;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.0;
uniform float scene_exposure : hint_range(0.5, 1.3, 0.01) = 1.0;
uniform float highlight_compression : hint_range(0.0, 0.5, 0.01) = 0.30;
uniform vec2 light_dir = vec2(-0.62, 1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.18;
uniform vec4 shadow_tint : source_color = vec4(0.34, 0.23, 0.30, 1.0);
uniform vec4 skin_warmth : source_color = vec4(0.72, 0.64, 0.70, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.015;
uniform vec4 rim_color : source_color = vec4(0.48, 0.28, 0.16, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.02;
uniform float rim_strength_cap : hint_range(0.0, 0.5, 0.01) = 0.035;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.27, 0.18, 0.16, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.018;
uniform vec4 ambient_color : source_color = vec4(0.16, 0.10, 0.14, 1.0);
uniform float ambient_amount : hint_range(0.0, 0.2, 0.005) = 0.012;
uniform vec4 lava_bounce_color : source_color = vec4(0.46, 0.22, 0.10, 1.0);
uniform float lava_bounce_amount : hint_range(0.0, 0.25, 0.005) = 0.012;
uniform float lava_bounce_start : hint_range(0.35, 0.9, 0.01) = 0.48;

varying vec4 node_modulate;


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

	float lit = dot(UV - vec2(0.5), direction);
	float light_side = smoothstep(-0.34, 0.34, lit);
	vec3 directional = mix(color * shadow_tint.rgb, color, light_side);
	color = mix(color, directional, backlight);
	color = mix(color, color * skin_warmth.rgb, warmth_amount);

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float dark_protection = 1.0 - luma * 0.72;
	vec3 ambient_lift = ambient_color.rgb * ambient_amount * dark_protection;
	color += ambient_lift;
	color += fill_color.rgb
			* fill_amount
			* (0.72 + light_side * 0.28)
			* dark_protection;
	float lower_forge_bounce = smoothstep(lava_bounce_start, 1.0, UV.y);
	lower_forge_bounce = floor(lower_forge_bounce * 4.0 + 0.5) / 4.0;
	color += lava_bounce_color.rgb
			* lava_bounce_amount
			* lower_forge_bounce
			* (1.0 - luma * 0.64);

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(
			TEXTURE,
			UV + direction * rim_offset).a;
	float source_facing_rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	float stable_rim_strength = min(rim_strength, rim_strength_cap);
	color += rim_color.rgb * source_facing_rim * stable_rim_strength;

	// Scene6 deliberately disables the full-body hit flash in its material.
	// Keeping the bounded route here preserves CharacterDisplay's shared API.
	luma = dot(color, vec3(0.299, 0.587, 0.114));
	float flash_response = mix(
			flash_dark_response,
			1.0,
			smoothstep(0.12, 0.55, luma));
	float stable_flash = clamp(flash_amount, 0.0, 1.0)
			* flash_peak_strength
			* flash_response;
	color = mix(color, flash_color.rgb, stable_flash);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha)
			* node_modulate;
}
