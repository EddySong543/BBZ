shader_type canvas_item;
render_mode unshaded, blend_mix;

// Atmospheric midground grade for the sparse sword-grave silhouettes.
uniform vec4 stone_tint : source_color = vec4(0.32, 0.38, 0.37, 1.0);
uniform vec4 mist_tint : source_color = vec4(0.58, 0.62, 0.59, 1.0);
uniform vec4 sun_rim_color : source_color = vec4(0.96, 0.66, 0.42, 1.0);
uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float contrast : hint_range(0.5, 1.2, 0.01) = 0.82;
uniform float brightness : hint_range(0.6, 1.3, 0.01) = 0.94;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform float atmosphere_strength : hint_range(0.0, 0.8, 0.01) = 0.28;
uniform float sun_rim_strength : hint_range(0.0, 0.5, 0.01) = 0.16;
uniform float sun_rim_width_px : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform vec2 sun_screen_pos = vec2(0.505, 0.68);
uniform float base_mist_strength : hint_range(0.0, 0.6, 0.01) = 0.24;
uniform float alpha_scale : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float palette_steps : hint_range(8.0, 64.0, 1.0) = 24.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		discard;
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(vec3(luma), tex.rgb, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;
	color = mix(
			color,
			stone_tint.rgb * mix(0.34, 1.0, luma),
			tint_strength);
	color = mix(color, mist_tint.rgb, atmosphere_strength);

	float toward_center = sign(sun_screen_pos.x - SCREEN_UV.x);
	vec2 rim_offset = vec2(
			toward_center * TEXTURE_PIXEL_SIZE.x * sun_rim_width_px,
			-TEXTURE_PIXEL_SIZE.y * sun_rim_width_px);
	float toward_sun_alpha = texture(TEXTURE, UV + rim_offset).a;
	float sun_rim = max(tex.a - toward_sun_alpha, 0.0);
	float sun_proximity = 1.0 - smoothstep(
			0.12,
			0.48,
			distance(SCREEN_UV, sun_screen_pos));
	color += sun_rim_color.rgb
			* sun_rim
			* sun_proximity
			* sun_rim_strength;

	float base_mist = smoothstep(0.62, 1.0, UV.y);
	color = mix(
			color,
			mist_tint.rgb,
			base_mist * base_mist_strength);
	color = floor(
			clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)
	) / palette_steps;
	float alpha = tex.a
			* alpha_scale
			* (1.0 - base_mist * base_mist_strength * 0.24);
	COLOR = vec4(color, alpha) * node_modulate;
}
