shader_type canvas_item;
render_mode unshaded;

// Scene3-only character light: a low warm key from the center horizon, cool
// cloud-sea bounce from below, and a one-pixel rim. The authored sprite color
// and nearest-neighbor silhouette stay intact.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.06;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.03;
uniform vec2 light_dir = vec2(1.0, 0.28);
uniform float backlight : hint_range(0.0, 1.0) = 0.06;
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.78, 0.76, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.04, 1.01, 0.96, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.025;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.86, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.08;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.60, 0.72, 0.72, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.05;
uniform vec4 dawn_key_color : source_color = vec4(1.0, 0.76, 0.52, 1.0);
uniform float dawn_key_amount : hint_range(0.0, 0.2, 0.005) = 0.035;
uniform vec4 cloud_bounce_color : source_color = vec4(0.48, 0.68, 0.68, 1.0);
uniform float cloud_bounce_amount : hint_range(0.0, 0.2, 0.005) = 0.045;
uniform float cloud_bounce_start : hint_range(0.35, 0.9) = 0.62;

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
	col += dawn_key_color.rgb
			* dawn_key_amount
			* light_side
			* dark_protection;

	float cloud_bounce = smoothstep(cloud_bounce_start, 1.0, UV.y);
	cloud_bounce = floor(cloud_bounce * 4.0 + 0.5) / 4.0;
	col += cloud_bounce_color.rgb
			* cloud_bounce_amount
			* cloud_bounce
			* (1.0 - luma * 0.62);

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(
			TEXTURE,
			UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	col += rim_color.rgb * rim * rim_strength;

	col = mix(col, flash_color.rgb, flash_amount);
	COLOR = vec4(
			clamp(col, vec3(0.0), vec3(1.0)),
			alpha) * node_modulate;
}
