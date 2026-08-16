shader_type canvas_item;
render_mode unshaded;

// Scene6 character lighting: dark red ambient, restrained side key, and a
// quantized orange bounce rising from the magma below the platform.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.04;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.04;
uniform float scene_exposure : hint_range(0.5, 1.3, 0.01) = 1.02;
uniform float highlight_compression : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform vec2 light_dir = vec2(-0.62, 1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.28;
uniform vec4 shadow_tint : source_color = vec4(0.44, 0.22, 0.24, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.04, 1.0, 0.94, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.06;
uniform vec4 rim_color : source_color = vec4(1.0, 0.56, 0.24, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.10;
uniform float rim_strength_cap : hint_range(0.0, 0.5, 0.01) = 0.28;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.62, 0.22, 0.12, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.075;
uniform vec4 ambient_color : source_color = vec4(0.34, 0.075, 0.10, 1.0);
uniform float ambient_amount : hint_range(0.0, 0.2, 0.005) = 0.045;
uniform vec4 lava_bounce_color : source_color = vec4(1.0, 0.25, 0.055, 1.0);
uniform float lava_bounce_amount : hint_range(0.0, 0.25, 0.005) = 0.15;
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
	color = mix(color, flash_color.rgb, flash_amount);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha)
			* node_modulate;
}
