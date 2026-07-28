shader_type canvas_item;
render_mode unshaded;

// Scene2-only character grade. It keeps the authored sprite pixels intact,
// then adds restrained daylight separation and a stepped jade water bounce.
// Capturing vertex COLOR prevents the texture from being multiplied twice.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.14;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.08;

uniform vec2 light_dir = vec2(1.0, -0.8);
uniform float backlight : hint_range(0.0, 1.0) = 0.08;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.68, 0.64, 1.0);

uniform vec4 skin_warmth : source_color = vec4(1.03, 1.01, 0.98, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.06;

uniform vec4 rim_color : source_color = vec4(0.62, 0.78, 0.70, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.34;
uniform float rim_width : hint_range(1.0, 8.0) = 2.5;

uniform vec4 fill_color : source_color = vec4(0.66, 0.78, 0.70, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.035;

uniform vec4 water_bounce_color : source_color = vec4(0.42, 0.67, 0.59, 1.0);
uniform float water_bounce_amount : hint_range(0.0, 0.25) = 0.022;
uniform float water_bounce_start : hint_range(0.35, 0.9) = 0.60;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 col = source.rgb;
	float alpha = source.a;
	vec2 direction = normalize(light_dir);

	// Counter only Scene2's restrained full-screen desaturation. Applying this
	// before the environmental light preserves the costume's authored hue
	// separation instead of tinting every dark ramp toward jade gray.
	float source_luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(source_luma), col, source_saturation);
	col = (col - vec3(0.5)) * source_contrast + vec3(0.5);
	col = clamp(col, vec3(0.0), vec3(1.0));

	float lit = dot(UV - vec2(0.5), direction);
	float shade = smoothstep(-0.35, 0.35, lit);
	vec3 directional = mix(col * shadow_tint.rgb, col, shade);
	col = mix(col, directional, backlight);
	col = mix(col, col * skin_warmth.rgb, warmth_amount);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float fill_weight = 0.65 + 0.35 * shade;
	col += fill_color.rgb
			* fill_amount
			* fill_weight
			* (1.0 - luma * 0.72);

	// Four stable horizontal bands read as pixel lighting instead of a smooth
	// airbrushed gradient. The effect remains confined to the lower sprite.
	float bounce = smoothstep(water_bounce_start, 1.0, UV.y);
	bounce = floor(bounce * 4.0 + 0.5) / 4.0;
	col += water_bounce_color.rgb
			* water_bounce_amount
			* bounce
			* (1.0 - luma * 0.60);

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(TEXTURE, UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	col += rim_color.rgb * rim * rim_strength;

	col = mix(col, flash_color.rgb, flash_amount);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), alpha) * node_modulate;
}
