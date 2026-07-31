shader_type canvas_item;
render_mode unshaded;

uniform sampler2D leaf_mask : filter_nearest, repeat_disable;
uniform sampler2D underpaint_texture : filter_nearest, repeat_disable;
uniform vec2 red_pivot = vec2(0.5, 0.25);
uniform vec2 green_pivot = vec2(0.75, 0.25);
uniform float motion_fps : hint_range(2.0, 12.0, 1.0) = 6.0;
uniform float cycle_sec : hint_range(5.0, 14.0, 0.25) = 8.5;
uniform float red_angle_deg : hint_range(0.0, 1.2, 0.05) = 0.85;
uniform float green_angle_deg : hint_range(0.0, 1.2, 0.05) = 1.0;
uniform float phase_offset = 0.4;

uniform vec4 night_tint : source_color = vec4(0.34, 0.48, 0.72, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.58;
uniform float saturation : hint_range(0.0, 1.0) = 0.48;
uniform float brightness : hint_range(0.0, 1.5) = 0.72;
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.92;
uniform vec4 shadow_tint : source_color = vec4(0.075, 0.105, 0.19, 1.0);
uniform float shadow_lift : hint_range(0.0, 1.0) = 0.22;
uniform vec4 rim_tint : source_color = vec4(0.46, 0.66, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_side : hint_range(-1.0, 1.0, 1.0) = 1.0;
uniform float rim_width : hint_range(1.0, 4.0, 1.0) = 2.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


vec2 inverse_rotate_pixel_uv(
		vec2 destination_uv,
		vec2 pivot_uv,
		float angle,
		vec2 source_size) {
	vec2 delta_px = (destination_uv - pivot_uv) * source_size;
	float cosine = cos(-angle);
	float sine = sin(-angle);
	vec2 source_px = vec2(
			delta_px.x * cosine - delta_px.y * sine,
			delta_px.x * sine + delta_px.y * cosine);
	source_px = floor(source_px + pivot_uv * source_size + 0.5);
	return source_px / source_size;
}


vec4 alpha_over(vec4 under, vec4 over) {
	float output_alpha = over.a + under.a * (1.0 - over.a);
	vec3 output_rgb = over.rgb + under.rgb * (1.0 - over.a);
	return vec4(output_rgb, output_alpha);
}


float alpha_over_value(float under, float over) {
	return over + under * (1.0 - over);
}


void fragment() {
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	float stepped_time = floor(TIME * motion_fps) / motion_fps;
	float base_phase = stepped_time * TAU / max(cycle_sec, 0.001)
			+ phase_offset;
	float red_angle = sin(base_phase) * radians(red_angle_deg);
	float green_angle = sin(base_phase * 0.87 + 1.4)
			* radians(green_angle_deg);

	vec4 local_mask = texture(leaf_mask, UV);
	local_mask.rgb *= local_mask.a;
	float red_here = local_mask.r;
	float green_here = local_mask.g;
	float moving_here = max(red_here, green_here);

	vec4 underpaint = texture(underpaint_texture, UV);
	underpaint.rgb *= underpaint.a;
	vec4 base = texture(TEXTURE, UV);
	base.a *= 1.0 - moving_here;
	base.rgb *= base.a;
	vec4 result = alpha_over(underpaint, base);

	vec2 red_uv = inverse_rotate_pixel_uv(
			UV, red_pivot, red_angle, source_size);
	float red_inside = step(0.0, red_uv.x) * step(red_uv.x, 1.0)
			* step(0.0, red_uv.y) * step(red_uv.y, 1.0);
	red_uv = clamp(red_uv, vec2(0.0), vec2(1.0));
	vec4 red_mask_sample = texture(leaf_mask, red_uv);
	vec4 red_color = texture(TEXTURE, red_uv);
	red_color.a *= red_mask_sample.r * red_mask_sample.a * red_inside;
	red_color.rgb *= red_color.a;
	result = alpha_over(result, red_color);

	vec2 green_uv = inverse_rotate_pixel_uv(
			UV, green_pivot, green_angle, source_size);
	float green_inside = step(0.0, green_uv.x) * step(green_uv.x, 1.0)
			* step(0.0, green_uv.y) * step(green_uv.y, 1.0);
	green_uv = clamp(green_uv, vec2(0.0), vec2(1.0));
	vec4 green_mask_sample = texture(leaf_mask, green_uv);
	vec4 green_color = texture(TEXTURE, green_uv);
	green_color.a *= green_mask_sample.g * green_mask_sample.a * green_inside;
	green_color.rgb *= green_color.a;
	result = alpha_over(result, green_color);

	if (result.a > 0.0) {
		result.rgb /= result.a;
	}
	vec4 tex = result;

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(vec3(luma), tex.rgb, saturation);
	vec3 moonlit = mix(muted, muted * night_tint.rgb, tint_strength);
	float shadow_mask = (1.0 - smoothstep(0.08, 0.46, luma)) * shadow_lift;
	moonlit = mix(moonlit, shadow_tint.rgb, shadow_mask);

	vec2 rim_uv = UV + vec2(
			rim_side * TEXTURE_PIXEL_SIZE.x * rim_width, 0.0);
	vec4 rim_mask = texture(leaf_mask, rim_uv);
	rim_mask.rgb *= rim_mask.a;
	float rim_moving = max(rim_mask.r, rim_mask.g);
	float rim_underpaint_alpha = texture(
			underpaint_texture, rim_uv).a;
	float rim_base_alpha = texture(TEXTURE, rim_uv).a
			* (1.0 - rim_moving);
	float rim_alpha = alpha_over_value(
			rim_underpaint_alpha, rim_base_alpha);

	vec2 rim_red_uv = inverse_rotate_pixel_uv(
			rim_uv, red_pivot, red_angle, source_size);
	float rim_red_inside = step(0.0, rim_red_uv.x)
			* step(rim_red_uv.x, 1.0)
			* step(0.0, rim_red_uv.y)
			* step(rim_red_uv.y, 1.0);
	rim_red_uv = clamp(rim_red_uv, vec2(0.0), vec2(1.0));
	vec4 rim_red_mask = texture(leaf_mask, rim_red_uv);
	float rim_red_alpha = texture(TEXTURE, rim_red_uv).a
			* rim_red_mask.r * rim_red_mask.a * rim_red_inside;
	rim_alpha = alpha_over_value(rim_alpha, rim_red_alpha);

	vec2 rim_green_uv = inverse_rotate_pixel_uv(
			rim_uv, green_pivot, green_angle, source_size);
	float rim_green_inside = step(0.0, rim_green_uv.x)
			* step(rim_green_uv.x, 1.0)
			* step(0.0, rim_green_uv.y)
			* step(rim_green_uv.y, 1.0);
	rim_green_uv = clamp(rim_green_uv, vec2(0.0), vec2(1.0));
	vec4 rim_green_mask = texture(leaf_mask, rim_green_uv);
	float rim_green_alpha = texture(TEXTURE, rim_green_uv).a
			* rim_green_mask.g * rim_green_mask.a
			* rim_green_inside;
	rim_alpha = alpha_over_value(rim_alpha, rim_green_alpha);

	float rim_edge = max(tex.a - rim_alpha, 0.0);
	moonlit += rim_tint.rgb * rim_edge * rim_strength;

	COLOR = vec4(
			clamp(moonlit * brightness, vec3(0.0), vec3(1.0)),
			tex.a * alpha_scale) * node_modulate;
}
