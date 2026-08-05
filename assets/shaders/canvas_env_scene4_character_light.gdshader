shader_type canvas_item;
render_mode unshaded;

// Scene4-only character grade. The key comes from the canopy opening above the
// arena; the low green fill is forest air, not inherited moon or water light.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.72, 0.82, 0.76, 1.0);
uniform float flash_peak_strength : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform float flash_dark_response : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.03;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.04;
uniform float scene_exposure : hint_range(0.5, 1.1, 0.01) = 0.82;
uniform float highlight_compression : hint_range(0.0, 0.5, 0.01) = 0.16;
uniform vec2 light_dir = vec2(0.48, -1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.30;
uniform vec4 shadow_tint : source_color = vec4(0.38, 0.52, 0.50, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.03, 1.01, 0.96, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.01;
uniform vec4 rim_color : source_color = vec4(0.52, 0.70, 0.64, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.045;
uniform float rim_peak_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.32, 0.52, 0.49, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.012;
uniform vec4 canopy_key_color : source_color = vec4(0.58, 0.72, 0.66, 1.0);
uniform float canopy_key_amount : hint_range(0.0, 0.2, 0.005) = 0.008;
uniform vec4 forest_ambient_color : source_color = vec4(0.40, 0.58, 0.55, 1.0);
uniform float forest_ambient_amount : hint_range(0.0, 0.5, 0.01) = 0.40;

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
	color += rim_color.rgb
			* rim
			* min(rim_strength, rim_peak_strength);

	// Battle juice drives flash_amount to 1.0 and can temporarily add more than
	// one full unit of rim strength. Scene4 is a closed-canopy environment, so
	// both signals are deliberately capped here. Dark pixels respond less than
	// existing highlights; this avoids a dark fighter jumping to a larger white
	// silhouette than a brighter opponent during the same hit event.
	luma = dot(color, vec3(0.299, 0.587, 0.114));
	float flash_response = mix(
			flash_dark_response,
			1.0,
			smoothstep(0.12, 0.55, luma));
	float stable_flash = clamp(flash_amount, 0.0, 1.0)
			* flash_peak_strength
			* flash_response;
	color = mix(color, flash_color.rgb, stable_flash);
	COLOR = vec4(
			clamp(color, vec3(0.0), vec3(1.0)),
			alpha) * node_modulate;
}
