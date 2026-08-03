shader_type canvas_item;
render_mode unshaded;

// Scene4-only character grade. The key comes from the canopy opening above the
// arena; the low green fill is forest air, not inherited moon or water light.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.04;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.02;
uniform vec2 light_dir = vec2(0.48, -1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.05;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.76, 0.66, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.03, 1.01, 0.96, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.025;
uniform vec4 rim_color : source_color = vec4(0.70, 0.86, 0.55, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.12;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.48, 0.69, 0.48, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.055;
uniform vec4 canopy_key_color : source_color = vec4(0.88, 0.94, 0.66, 1.0);
uniform float canopy_key_amount : hint_range(0.0, 0.2, 0.005) = 0.035;
uniform vec4 forest_ambient_color : source_color = vec4(0.62, 0.78, 0.66, 1.0);
uniform float forest_ambient_amount : hint_range(0.0, 0.5, 0.01) = 0.28;

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

	float directional_sample = dot(UV - vec2(0.5), direction);
	float light_side = smoothstep(-0.34, 0.34, directional_sample);
	vec3 directional = mix(color * shadow_tint.rgb, color, light_side);
	color = mix(color, directional, backlight);
	color = mix(color, color * skin_warmth.rgb, warmth_amount);

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float dark_protection = 1.0 - luma * 0.72;
	color += fill_color.rgb
			* fill_amount
			* (0.72 + light_side * 0.28)
			* dark_protection;

	float canopy_key = 1.0 - smoothstep(0.05, 0.68, UV.y);
	canopy_key = floor(canopy_key * 4.0 + 0.5) / 4.0;
	color += canopy_key_color.rgb
			* canopy_key_amount
			* canopy_key
			* dark_protection;

	// Dense leaves reduce the open-sky energy and push a restrained green cast
	// into midtones and shadows. Highlights remain readable instead of turning
	// the whole fighter into a flat green silhouette.
	luma = dot(color, vec3(0.299, 0.587, 0.114));
	float forest_mask = 0.58 + (1.0 - luma) * 0.42;
	color = mix(
			color,
			color * forest_ambient_color.rgb,
			forest_ambient_amount * forest_mask);

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(
			TEXTURE,
			UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	color += rim_color.rgb * rim * rim_strength;

	color = mix(color, flash_color.rgb, flash_amount);
	COLOR = vec4(
			clamp(color, vec3(0.0), vec3(1.0)),
			alpha) * node_modulate;
}
