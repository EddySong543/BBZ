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
uniform vec2 light_dir = vec2(1.0, -0.8);
uniform vec4 light_color : source_color = vec4(1.0, 0.78, 0.58, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.19, 0.28, 0.27, 1.0);
uniform float receiver_light_strength : hint_range(0.0, 0.4, 0.01) = 0.13;
uniform float receiver_shadow_strength : hint_range(0.0, 0.25, 0.01) = 0.055;
uniform float receiver_rim_strength : hint_range(0.0, 0.5, 0.01) = 0.16;
uniform float receiver_rim_width : hint_range(1.0, 3.0, 1.0) = 1.0;
uniform vec2 scene_light_source_uv = vec2(0.90, -0.08);
uniform vec2 scene_light_target_uv = vec2(0.47, 0.78);
uniform float scene_light_top_width : hint_range(0.02, 0.3, 0.01) = 0.10;
uniform float scene_light_bottom_width : hint_range(0.1, 0.6, 0.01) = 0.40;
uniform vec2 scene_light_pool_center = vec2(0.63, 0.28);
uniform vec2 scene_light_pool_radius = vec2(0.56, 0.40);
uniform vec2 focus_quiet_center_a = vec2(0.25, 0.61);
uniform vec2 focus_quiet_center_b = vec2(0.735, 0.61);
uniform vec2 focus_quiet_radius = vec2(0.115, 0.17);
uniform float focus_quiet_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float focus_quiet_saturation : hint_range(0.85, 1.0, 0.01) = 0.98;
uniform float focus_quiet_contrast : hint_range(0.75, 1.0, 0.01) = 0.90;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float scene2_light_field(vec2 screen_uv) {
	vec2 grid = vec2(480.0, 270.0);
	vec2 suv = (floor(screen_uv * grid) + vec2(0.5)) / grid;
	vec2 axis = scene_light_target_uv - scene_light_source_uv;
	float raw_along = dot(suv - scene_light_source_uv, axis)
			/ max(dot(axis, axis), 0.0001);
	float along = clamp(raw_along, 0.0, 1.0);
	vec2 center = scene_light_source_uv + axis * along;
	vec2 normal = normalize(vec2(-axis.y, axis.x));
	float width = mix(scene_light_top_width, scene_light_bottom_width, along);
	float row_break = (
			fract(floor(suv.y * 72.0) * 0.6180339) - 0.5) * 0.014;
	float across = abs(dot(suv - center, normal));
	float cone = 1.0 - smoothstep(
			width + row_break,
			width + row_break + 0.045,
			across);
	float reach = smoothstep(-0.08, 0.04, raw_along)
			* (1.0 - smoothstep(0.86, 1.08, raw_along));
	vec2 pool_delta = (suv - scene_light_pool_center)
			/ max(scene_light_pool_radius, vec2(0.001));
	float upper_pool = 1.0 - smoothstep(0.70, 1.0, length(pool_delta));
	float field = max(cone * reach, upper_pool * 0.35);
	field *= 1.0 - smoothstep(0.78, 0.98, suv.y);
	return floor(clamp(field, 0.0, 1.0) * 4.0 + 0.5) / 4.0;
}


float focus_quiet_mask(vec2 screen_uv) {
	vec2 stepped_uv = (
			floor(screen_uv * vec2(480.0, 270.0)) + vec2(0.5)
	) / vec2(480.0, 270.0);
	vec2 delta_a = (stepped_uv - focus_quiet_center_a)
			/ max(focus_quiet_radius, vec2(0.001));
	vec2 delta_b = (stepped_uv - focus_quiet_center_b)
			/ max(focus_quiet_radius, vec2(0.001));
	float mask_a = 1.0 - smoothstep(0.58, 1.0, length(delta_a));
	float mask_b = 1.0 - smoothstep(0.58, 1.0, length(delta_b));
	return max(mask_a, mask_b) * focus_quiet_strength;
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
	vec2 direction = normalize(light_dir);
	vec2 pixel_uv = (
			floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	float luma = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	float facing = scene2_light_field(SCREEN_UV);
	float petal_plane = smoothstep(0.20, 0.78, luma);
	float light_mask = petal_plane * facing;
	float shadow_mask = (1.0 - facing) * (1.0 - petal_plane * 0.68);
	result.rgb *= 1.0 + light_mask * receiver_light_strength;
	result.rgb += light_color.rgb
			* light_mask * receiver_light_strength * 0.14;
	result.rgb = mix(
			result.rgb,
			result.rgb * shadow_color.rgb,
			shadow_mask * receiver_shadow_strength);
	float toward_light_alpha = texture(
			TEXTURE,
			UV + direction * TEXTURE_PIXEL_SIZE * receiver_rim_width).a;
	float light_rim = max(result.a - toward_light_alpha, 0.0);
	result.rgb += light_color.rgb * light_rim * receiver_rim_strength;
	float focus_quiet = focus_quiet_mask(SCREEN_UV);
	float focus_luma = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	vec3 quiet_color = mix(
			vec3(focus_luma), result.rgb, focus_quiet_saturation);
	quiet_color = (
			quiet_color - vec3(0.5)
	) * focus_quiet_contrast + vec3(0.5);
	result.rgb = mix(result.rgb, quiet_color, focus_quiet);
	COLOR = result * node_modulate;
}
