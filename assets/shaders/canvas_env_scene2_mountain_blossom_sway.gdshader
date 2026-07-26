shader_type canvas_item;

// Scene2 left-mountain grade plus three rigid, source-pixel-snapped blossom
// branch tips. The masks cover only branches protruding into transparent space,
// so the mountain face and tree roots never move and need no hidden underpaint.
uniform sampler2D branch_mask : filter_nearest, repeat_disable;
uniform float motion_fps : hint_range(2.0, 10.0, 1.0) = 5.0;
uniform float cycle_sec : hint_range(6.0, 16.0, 0.5) = 9.5;
uniform float max_angle_deg : hint_range(0.0, 3.0, 0.05) = 2.2;
uniform float phase_offset = 0.45;

uniform float saturation : hint_range(0.0, 1.25, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.25, 0.01) = 1.0;
uniform float brightness : hint_range(0.5, 1.25, 0.01) = 1.0;
uniform vec4 atmosphere_color : source_color = vec4(0.62, 0.73, 0.73, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform vec2 quiet_center = vec2(0.5);
uniform vec2 quiet_radius = vec2(0.2);
uniform float quiet_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 quiet_color : source_color = vec4(0.72, 0.76, 0.72, 1.0);
uniform float quiet_saturation : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float quiet_contrast : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float quiet_lift : hint_range(0.0, 0.2, 0.01) = 0.0;

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


void fragment() {
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	float stepped_time = floor(TIME * motion_fps) / motion_fps;
	float base_phase = stepped_time * TAU / max(cycle_sec, 0.001)
			+ phase_offset;
	float maximum = radians(max_angle_deg);
	float upper_angle = sin(base_phase) * maximum;
	float middle_angle = sin(base_phase * 0.87 + 1.65) * maximum * 0.86;
	float lower_angle = sin(base_phase * 1.12 + 3.1) * maximum * 0.72;

	vec4 local_mask = texture(branch_mask, UV);
	local_mask.rgb *= local_mask.a;
	float moving_here = max(
			local_mask.r,
			max(local_mask.g, local_mask.b));

	vec4 base_color = texture(TEXTURE, UV);
	base_color.a *= 1.0 - moving_here;
	base_color.rgb *= base_color.a;
	vec4 result = base_color;

	vec2 upper_uv = inverse_rotate_pixel_uv(
			UV, vec2(0.3934, 0.4124), upper_angle, source_size);
	float upper_inside = step(0.0, upper_uv.x) * step(upper_uv.x, 1.0)
			* step(0.0, upper_uv.y) * step(upper_uv.y, 1.0);
	upper_uv = clamp(upper_uv, vec2(0.0), vec2(1.0));
	vec4 upper_mask = texture(branch_mask, upper_uv);
	vec4 upper_color = texture(TEXTURE, upper_uv);
	upper_color.a *= upper_mask.r * upper_mask.a * upper_inside;
	upper_color.rgb *= upper_color.a;
	result = alpha_over(result, upper_color);

	vec2 middle_uv = inverse_rotate_pixel_uv(
			UV, vec2(0.4180, 0.4691), middle_angle, source_size);
	float middle_inside = step(0.0, middle_uv.x) * step(middle_uv.x, 1.0)
			* step(0.0, middle_uv.y) * step(middle_uv.y, 1.0);
	middle_uv = clamp(middle_uv, vec2(0.0), vec2(1.0));
	vec4 middle_mask = texture(branch_mask, middle_uv);
	vec4 middle_color = texture(TEXTURE, middle_uv);
	middle_color.a *= middle_mask.g * middle_mask.a * middle_inside;
	middle_color.rgb *= middle_color.a;
	result = alpha_over(result, middle_color);

	vec2 lower_uv = inverse_rotate_pixel_uv(
			UV, vec2(0.4426, 0.5567), lower_angle, source_size);
	float lower_inside = step(0.0, lower_uv.x) * step(lower_uv.x, 1.0)
			* step(0.0, lower_uv.y) * step(lower_uv.y, 1.0);
	lower_uv = clamp(lower_uv, vec2(0.0), vec2(1.0));
	vec4 lower_mask = texture(branch_mask, lower_uv);
	vec4 lower_color = texture(TEXTURE, lower_uv);
	lower_color.a *= lower_mask.b * lower_mask.a * lower_inside;
	lower_color.rgb *= lower_color.a;
	result = alpha_over(result, lower_color);

	if (result.a > 0.0) {
		result.rgb /= result.a;
	}
	float luma = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(luma), result.rgb, saturation);
	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	col *= brightness;
	col = mix(col, atmosphere_color.rgb, atmosphere_strength);

	vec2 pixel_uv = (
			floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	vec2 quiet_delta = (pixel_uv - quiet_center) / max(
			quiet_radius, vec2(0.001));
	float quiet_mask = (
			1.0 - smoothstep(0.72, 1.0, length(quiet_delta))) * quiet_strength;
	float quiet_luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 quiet_col = mix(vec3(quiet_luma), col, quiet_saturation);
	quiet_col = mix(quiet_color.rgb, quiet_col, quiet_contrast)
			+ vec3(quiet_lift);
	col = mix(col, quiet_col, quiet_mask);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), result.a)
			* vec4(result.rgb, result.a) * node_modulate;
}
