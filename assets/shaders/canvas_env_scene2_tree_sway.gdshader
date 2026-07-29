shader_type canvas_item;
render_mode unshaded;

// Source-resolution mask channels isolate three terminal branch groups and a
// small hanging bouquet. A separately painted hidden-trunk texture sits below
// every moving piece, preventing background pinholes when a branch pivots away.
// Unmasked pixels (roots, trunk, and load-bearing limbs) always sample the
// original UV and therefore remain completely static.
uniform sampler2D branch_mask : filter_nearest, repeat_disable;
uniform sampler2D underpaint_texture : filter_nearest, repeat_disable;
uniform float motion_fps : hint_range(2.0, 12.0, 1.0) = 6.0;
uniform float cycle_sec : hint_range(4.0, 16.0, 0.5) = 8.5;
uniform float max_angle_deg : hint_range(0.0, 1.5, 0.05) = 0.75;
uniform float bouquet_cycle_sec : hint_range(3.0, 10.0, 0.25) = 5.75;
uniform float bouquet_angle_deg : hint_range(0.0, 2.0, 0.05) = 1.25;
uniform float phase_offset = 0.7;

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
	float max_angle = radians(max_angle_deg);

	// Each branch group hinges around its real attachment point. Slightly
	// different periods prevent mechanical unison without introducing ripples.
	float left_angle = sin(base_phase) * max_angle;
	float upper_angle = sin(base_phase * 0.91 + 1.2) * max_angle * 0.72;
	float right_angle = sin(base_phase * 1.08 + 2.35) * max_angle * 0.82;
	float bouquet_angle = sin(
			stepped_time * TAU / max(bouquet_cycle_sec, 0.001)
					+ phase_offset + 0.35) * radians(bouquet_angle_deg);

	vec4 local_mask = texture(branch_mask, UV);
	local_mask.rgb *= local_mask.a;
	float bouquet_here = min(local_mask.r, local_mask.g);
	float left_here = local_mask.r * (1.0 - local_mask.g);
	float upper_here = local_mask.g * (1.0 - local_mask.r);
	float right_here = local_mask.b;
	float moving_here = max(
			max(left_here, upper_here),
			max(right_here, bouquet_here));

	vec4 underpaint_color = texture(underpaint_texture, UV);
	underpaint_color.rgb *= underpaint_color.a;
	vec4 base_color = texture(TEXTURE, UV);
	base_color.a *= 1.0 - moving_here;
	base_color.rgb *= base_color.a;

	vec4 result = alpha_over(underpaint_color, base_color);
	vec2 left_uv = inverse_rotate_pixel_uv(
			UV, vec2(0.394, 0.536), left_angle, source_size);
	float left_inside = step(0.0, left_uv.x) * step(left_uv.x, 1.0)
			* step(0.0, left_uv.y) * step(left_uv.y, 1.0);
	left_uv = clamp(left_uv, vec2(0.0), vec2(1.0));
	vec4 left_mask = texture(branch_mask, left_uv);
	vec4 left_color = texture(TEXTURE, left_uv);
	left_color.a *= left_mask.r * (1.0 - left_mask.g)
			* left_mask.a * left_inside;
	left_color.rgb *= left_color.a;
	result = alpha_over(result, left_color);

	vec2 upper_uv = inverse_rotate_pixel_uv(
			UV, vec2(0.577, 0.488), upper_angle, source_size);
	float upper_inside = step(0.0, upper_uv.x) * step(upper_uv.x, 1.0)
			* step(0.0, upper_uv.y) * step(upper_uv.y, 1.0);
	upper_uv = clamp(upper_uv, vec2(0.0), vec2(1.0));
	vec4 upper_mask = texture(branch_mask, upper_uv);
	vec4 upper_color = texture(TEXTURE, upper_uv);
	upper_color.a *= upper_mask.g * (1.0 - upper_mask.r)
			* upper_mask.a * upper_inside;
	upper_color.rgb *= upper_color.a;
	result = alpha_over(result, upper_color);

	vec2 right_uv = inverse_rotate_pixel_uv(
			UV, vec2(0.760, 0.560), right_angle, source_size);
	float right_inside = step(0.0, right_uv.x) * step(right_uv.x, 1.0)
			* step(0.0, right_uv.y) * step(right_uv.y, 1.0);
	right_uv = clamp(right_uv, vec2(0.0), vec2(1.0));
	vec4 right_color = texture(TEXTURE, right_uv);
	vec4 right_mask = texture(branch_mask, right_uv);
	right_color.a *= right_mask.b * right_mask.a * right_inside;
	right_color.rgb *= right_color.a;
	result = alpha_over(result, right_color);

	vec2 bouquet_uv = inverse_rotate_pixel_uv(
			UV, vec2(0.572, 0.632), bouquet_angle, source_size);
	float bouquet_inside = step(0.0, bouquet_uv.x) * step(bouquet_uv.x, 1.0)
			* step(0.0, bouquet_uv.y) * step(bouquet_uv.y, 1.0);
	bouquet_uv = clamp(bouquet_uv, vec2(0.0), vec2(1.0));
	vec4 bouquet_mask = texture(branch_mask, bouquet_uv);
	vec4 bouquet_color = texture(TEXTURE, bouquet_uv);
	bouquet_color.a *= min(bouquet_mask.r, bouquet_mask.g)
			* bouquet_mask.a * bouquet_inside;
	bouquet_color.rgb *= bouquet_color.a;
	result = alpha_over(result, bouquet_color);

	if (result.a > 0.0) {
		result.rgb /= result.a;
	}
	COLOR = result * node_modulate;
}
