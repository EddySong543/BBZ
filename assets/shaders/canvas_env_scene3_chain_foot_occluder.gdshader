shader_type canvas_item;
render_mode unshaded, blend_mix;

// Re-render only the upper contour of links directly under each fighter.
// This narrow strip sits above the character layer and lightly covers shoes.
uniform float p1_foot_center : hint_range(0.0, 1.0, 0.001) = 0.175;
uniform float p2_foot_center : hint_range(0.0, 1.0, 0.001) = 0.83;
uniform float foot_half_width : hint_range(0.02, 0.2, 0.005) = 0.042;
uniform float foot_feather : hint_range(0.005, 0.08, 0.005) = 0.012;
uniform float edge_sample_px : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform vec4 tint_color : source_color = vec4(0.38, 0.47, 0.46, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.015, 0.055, 0.06, 1.0);
uniform vec4 dawn_rim_color : source_color = vec4(0.9, 0.64, 0.35, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float rim_strength : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float alpha_scale : hint_range(0.0, 1.0, 0.01) = 0.88;
uniform float palette_steps : hint_range(8.0, 96.0, 1.0) = 32.0;


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float sample_offset = TEXTURE_PIXEL_SIZE.y * edge_sample_px;
	float alpha_above = texture(
			TEXTURE, UV - vec2(0.0, sample_offset)).a;
	float upper_edge = max(tex.a - alpha_above, 0.0);
	float p1_foot_zone = 1.0 - smoothstep(
			foot_half_width,
			foot_half_width + foot_feather,
			abs(UV.x - p1_foot_center));
	float p2_foot_zone = 1.0 - smoothstep(
			foot_half_width,
			foot_half_width + foot_feather,
			abs(UV.x - p2_foot_center));
	float foot_zone = max(p1_foot_zone, p2_foot_zone);
	float alpha = upper_edge * foot_zone * alpha_scale;
	if (alpha <= 0.001) {
		discard;
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(
			tex.rgb,
			tint_color.rgb * max(luma, 0.18),
			tint_strength);
	color = mix(
			color,
			color * shadow_color.rgb,
			shadow_strength * smoothstep(0.32, 0.96, UV.y));
	float rim = smoothstep(0.38, 1.0, UV.x)
			* (1.0 - smoothstep(0.0, 0.24, UV.y));
	color += dawn_rim_color.rgb * rim * rim_strength * alpha;
	color = floor(
			clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)
	) / palette_steps;
	COLOR = vec4(color, alpha);
}
