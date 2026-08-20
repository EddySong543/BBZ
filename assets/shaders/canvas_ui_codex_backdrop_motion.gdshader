shader_type canvas_item;
render_mode unshaded;

uniform float drift_pixels : hint_range(0.0, 8.0, 0.25) = 4.0;
uniform float drift_period : hint_range(8.0, 40.0, 0.5) = 22.0;
uniform float moving_mix : hint_range(0.0, 0.15, 0.005) = 0.08;
uniform float breathe_strength : hint_range(0.0, 0.03, 0.001) = 0.012;
uniform float breathe_period : hint_range(8.0, 30.0, 0.5) = 18.0;

void fragment() {
	vec4 vertex_tint = COLOR;
	vec2 safe_uv = (UV - vec2(0.5)) * 0.985 + vec2(0.5);
	float drift_phase = TIME * 6.28318530718 / drift_period;
	vec2 drift = vec2(sin(drift_phase), cos(drift_phase * 0.73))
			* drift_pixels * TEXTURE_PIXEL_SIZE;
	vec4 fixed_layer = texture(TEXTURE, safe_uv);
	vec2 moving_uv = clamp(safe_uv + drift, vec2(0.002), vec2(0.998));
	vec2 moving_pixel = moving_uv / TEXTURE_PIXEL_SIZE - vec2(0.5);
	vec2 base_pixel = floor(moving_pixel);
	vec2 blend_amount = smoothstep(vec2(0.0), vec2(1.0), fract(moving_pixel));
	vec2 uv00 = (base_pixel + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	vec2 uv10 = uv00 + vec2(TEXTURE_PIXEL_SIZE.x, 0.0);
	vec2 uv01 = uv00 + vec2(0.0, TEXTURE_PIXEL_SIZE.y);
	vec2 uv11 = uv00 + TEXTURE_PIXEL_SIZE;
	vec4 moving_top = mix(texture(TEXTURE, uv00), texture(TEXTURE, uv10), blend_amount.x);
	vec4 moving_bottom = mix(texture(TEXTURE, uv01), texture(TEXTURE, uv11), blend_amount.x);
	vec4 moving_layer = mix(moving_top, moving_bottom, blend_amount.y);
	vec3 color = mix(fixed_layer.rgb, moving_layer.rgb, moving_mix);

	vec2 centered = (UV - vec2(0.5)) * vec2(1.0, 0.78);
	float center_mask = 1.0 - smoothstep(0.08, 0.72, length(centered));
	float breathe = sin(TIME * 6.28318530718 / breathe_period)
			* breathe_strength * center_mask;
	color *= 1.0 + breathe;
	COLOR = vec4(color, fixed_layer.a) * vertex_tint;
}
