shader_type canvas_item;
render_mode unshaded;

// Scene5 hybrid wheat wind:
// - close/mid wheat uses continuous main + detail vertex bending;
// - the pixel-sized horizon uses broad moving light fronts instead of being
//   distorted like individual stalks;
// - the source texture remains complete and fully visible.
uniform float clip_top : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float mirror_texture : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float tip_y : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float root_y : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float geometry_y_start : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float geometry_y_feather : hint_range(0.0, 0.2, 0.005) = 0.04;
uniform float cluster_count : hint_range(2.0, 24.0, 1.0) = 12.0;
uniform float cycle_sec : hint_range(2.0, 16.0, 0.1) = 7.0;
uniform float phase_seed : hint_range(0.0, 64.0, 0.01) = 0.0;
uniform float sway_px : hint_range(0.0, 10.0, 0.1) = 3.0;
uniform float detail_px : hint_range(0.0, 4.0, 0.1) = 0.8;
uniform float detail_frequency : hint_range(1.0, 8.0, 0.1) = 3.2;
uniform float vertical_phase : hint_range(0.0, 8.0, 0.1) = 2.4;
uniform float inertia_mix : hint_range(0.0, 0.7, 0.01) = 0.3;
uniform float bend_power : hint_range(0.8, 2.2, 0.05) = 1.55;
uniform float field_wave_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float field_wave_speed : hint_range(0.0, 0.5, 0.005) = 0.075;
uniform float field_wave_phase : hint_range(0.0, 1.0, 0.001) = 0.055;
uniform float field_wave_scale : hint_range(0.2, 4.0, 0.05) = 1.25;
uniform float field_wave_y_start : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float field_wave_y_end : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float field_wave_feather : hint_range(0.0, 0.2, 0.005) = 0.05;
uniform vec4 field_wave_color : source_color = vec4(1.0, 0.82, 0.36, 1.0);
uniform float field_highlight_threshold : hint_range(0.4, 0.95, 0.01) = 0.72;
uniform float field_highlight_softness : hint_range(0.01, 0.2, 0.005) = 0.06;
uniform float field_highlight_rest : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float field_highlight_demote : hint_range(0.0, 0.6, 0.01) = 0.32;
uniform float field_wave_width : hint_range(0.04, 0.4, 0.01) = 0.17;
uniform float field_wave_secondary_offset : hint_range(0.1, 0.8, 0.01) = 0.43;
uniform float field_wave_secondary_strength : hint_range(0.0, 1.0, 0.01) = 0.48;
uniform vec4 depth_haze_color : source_color = vec4(0.92, 0.73, 0.55, 1.0);
uniform float depth_haze_strength : hint_range(0.0, 0.4, 0.005) = 0.0;
uniform float shape_wave_vertical_px : hint_range(0.0, 10.0, 0.1) = 0.0;
uniform float shape_wave_horizontal_px : hint_range(0.0, 8.0, 0.1) = 0.0;
uniform float shape_wave_cycles : hint_range(0.5, 4.0, 0.05) = 1.6;
uniform float shape_wave_y_start : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float shape_wave_y_end : hint_range(0.0, 1.0, 0.01) = 0.86;
uniform float shape_wave_feather : hint_range(0.0, 0.2, 0.005) = 0.06;
uniform float gust_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float gust_direction : hint_range(-1.0, 1.0, 0.1) = 1.0;
uniform float gust_px : hint_range(0.0, 16.0, 0.1) = 7.0;
uniform float crop_circle_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float crop_circle_reveal : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec2 crop_circle_center = vec2(0.5, 0.55);
uniform float crop_circle_depth_scale : hint_range(0.7, 1.1, 0.01) = 1.0;
uniform vec2 crop_circle_half_size = vec2(0.36, 0.085);


float smooth_triangle_wave(float value) {
	float triangle = abs(fract(value + 0.5) * 2.0 - 1.0);
	float smoothed = triangle * triangle * (3.0 - 2.0 * triangle);
	return smoothed * 2.0 - 1.0;
}


float field_band_mask(float y) {
	float enter = smoothstep(
			field_wave_y_start - field_wave_feather,
			field_wave_y_start + field_wave_feather,
			y);
	float leave = 1.0 - smoothstep(
			field_wave_y_end - field_wave_feather,
			field_wave_y_end + field_wave_feather,
			y);
	return enter * leave;
}


float source_highlight_mask(vec4 source_texel) {
	float source_luminance = dot(
			source_texel.rgb,
			vec3(0.2126, 0.7152, 0.0722));
	float warm_gold = smoothstep(
			0.08,
			0.34,
			source_texel.r - source_texel.b);
	return smoothstep(
			field_highlight_threshold,
			field_highlight_threshold + field_highlight_softness,
			source_luminance) * warm_gold * source_texel.a;
}


float moving_wave_mask(vec2 uv) {
	float wave_center = fract(TIME * field_wave_speed + field_wave_phase);
	float primary_distance = abs(fract(uv.x - wave_center + 0.5) - 0.5);
	float primary_wave = 1.0 - smoothstep(
			field_wave_width * 0.58,
			field_wave_width,
			primary_distance);
	float secondary_center = fract(wave_center - field_wave_secondary_offset);
	float secondary_distance = abs(
			fract(uv.x - secondary_center + 0.5) - 0.5);
	float secondary_wave = 1.0 - smoothstep(
			field_wave_width * 0.38,
			field_wave_width * 0.72,
			secondary_distance);
	return max(
			primary_wave,
			secondary_wave * field_wave_secondary_strength);
}


float shape_wave_mask(float y) {
	float enter = smoothstep(
			shape_wave_y_start - shape_wave_feather,
			shape_wave_y_start + shape_wave_feather,
			y);
	float leave = 1.0 - smoothstep(
			shape_wave_y_end - shape_wave_feather,
			shape_wave_y_end + shape_wave_feather,
			y);
	float root_pin = clamp(
			(root_y - y) / max(root_y - shape_wave_y_start, 0.001),
			0.0,
			1.0);
	return enter * leave * pow(root_pin, 0.72);
}


vec2 traveling_shape_wave(vec2 uv) {
	float wave_center = TIME * field_wave_speed + field_wave_phase;
	float phase = (uv.x - wave_center) * TAU * shape_wave_cycles;
	float broad_lift = cos(phase);
	float broken_lift = sin(
			phase * 1.82 + uv.y * vertical_phase - 0.72) * 0.26;
	float vertical_motion = clamp(broad_lift + broken_lift, -1.0, 1.0);
	float horizontal_motion = sin(phase - 0.78);
	horizontal_motion += sin(phase * 1.47 + uv.y * 2.2) * 0.22;
	return vec2(vertical_motion, horizontal_motion);
}


vec2 crop_circle_space(vec2 screen_uv) {
	vec2 half_size = crop_circle_half_size * crop_circle_depth_scale;
	return (screen_uv - crop_circle_center) / max(half_size, vec2(0.001));
}


float crop_circle_mask(vec2 screen_uv) {
	vec2 circle_uv = crop_circle_space(screen_uv);
	float radius = length(circle_uv);
	float outer_oval = 1.0 - smoothstep(
			0.12,
			0.26,
			abs(radius - 0.88));
	vec2 inner_space = vec2(
			(circle_uv.x + 0.08) / 0.64,
			circle_uv.y / 0.7);
	float inner_oval = 1.0 - smoothstep(
			0.12,
			0.25,
			abs(length(inner_space) - 0.64));
	float upper_pressed_lane = 1.0 - smoothstep(
			0.1,
			0.26,
			abs(circle_uv.y - 0.2 - sin(circle_uv.x * 3.7) * 0.1));
	float lower_pressed_lane = 1.0 - smoothstep(
			0.1,
			0.26,
			abs(circle_uv.y + 0.2 + sin(circle_uv.x * 3.7) * 0.1));
	float lane_extent = 1.0 - smoothstep(0.58, 0.82, abs(circle_uv.x));
	float pressed_lane = max(upper_pressed_lane, lower_pressed_lane) * lane_extent;
	float center_lay = (1.0 - smoothstep(
			0.22,
			0.5,
			length(vec2(circle_uv.x / 0.5, circle_uv.y / 0.68)))) * 0.7;
	float broken_rows = mix(
			0.92,
			1.0,
			smoothstep(-0.25, 0.45, sin(circle_uv.x * 27.0 + circle_uv.y * 9.0)));
	float formation = max(
			max(outer_oval, inner_oval * 0.94),
			max(pressed_lane * 0.88, center_lay));
	float formation_edge = 1.0 - smoothstep(0.94, 1.06, radius);
	return clamp(formation * formation_edge * broken_rows, 0.0, 1.0);
}


vec2 crop_circle_uv_offset(vec2 screen_uv, float pressed_mask) {
	vec2 circle_uv = crop_circle_space(screen_uv);
	float radius = max(length(circle_uv), 0.001);
	vec2 radial = circle_uv / radius;
	vec2 tangent = vec2(-radial.y, radial.x);
	float comb_direction = sin(circle_uv.x * 5.4 + circle_uv.y * 2.8);
	vec2 laid_wheat = tangent * comb_direction * vec2(0.014, 0.008);
	laid_wheat += vec2(radial.x * 0.006, 0.019 + abs(radial.x) * 0.006);
	return laid_wheat * pressed_mask;
}


void vertex() {
	float geometry_mask = smoothstep(
			geometry_y_start - geometry_y_feather,
			geometry_y_start + geometry_y_feather,
			UV.y);
	float height_ratio = clamp(
			(root_y - UV.y) / max(root_y - geometry_y_start, 0.001),
			0.0,
			1.0);
	float bend_weight = pow(height_ratio, bend_power) * geometry_mask;
	float edge_pin = smoothstep(0.0, 0.035, UV.x)
			* (1.0 - smoothstep(0.965, 1.0, UV.x));

	float time_phase = TIME * TAU / max(cycle_sec, 0.001);
	float spatial_phase = UV.x * TAU * 1.18
			+ UV.y * vertical_phase + phase_seed * 0.31;
	float main_bend = sin(time_phase + spatial_phase);
	float lagging_bend = sin(
			time_phase * 0.58 + spatial_phase * 0.72 - 0.85);
	float body_motion = mix(
			main_bend,
			main_bend * 0.7 + lagging_bend * 0.55,
			inertia_mix);
	float detail_motion = smooth_triangle_wave(
			TIME / max(cycle_sec * 0.46, 0.001)
			+ UV.x * detail_frequency
			+ sin(UV.x * TAU * cluster_count + phase_seed) * 0.035);
	float gust_ripple = sin(
			UV.x * TAU * 1.55
			- TIME * 4.2 * gust_direction
			+ phase_seed) * 0.16;
	float directional_weight = step(0.5, abs(gust_direction));
	float dual_direction = -sign(UV.x - 0.5);
	float response_direction = mix(
			dual_direction,
			gust_direction,
			directional_weight);
	float gust_motion = response_direction * (0.84 + gust_ripple);
	float wave_geometry_mask = shape_wave_mask(UV.y) * edge_pin;
	vec2 shape_motion = traveling_shape_wave(UV);

	float offset_px = sway_px * body_motion;
	offset_px += detail_px * detail_motion;
	offset_px += gust_strength * gust_px * gust_motion;
	VERTEX.x += offset_px * bend_weight * edge_pin;

	VERTEX.x += shape_motion.y * shape_wave_horizontal_px
			* wave_geometry_mask;
	VERTEX.y -= shape_motion.x * shape_wave_vertical_px
			* wave_geometry_mask;
}


void fragment() {
	if (UV.y < clip_top) {
		discard;
	}
	vec2 source_uv = vec2(mix(UV.x, 1.0 - UV.x, mirror_texture), UV.y);
	vec2 crop_space = crop_circle_space(SCREEN_UV);
	float crop_radius = length(crop_space);
	float crop_pattern = crop_circle_mask(SCREEN_UV);
	float crop_reveal_gate = smoothstep(
			crop_radius - 0.14,
			crop_radius + 0.08,
			crop_circle_reveal * 1.08);
	float crop_pressed = crop_pattern * crop_reveal_gate * crop_circle_strength;
	vec2 crop_source_uv = clamp(
			source_uv + crop_circle_uv_offset(SCREEN_UV, crop_pressed),
			vec2(0.001),
			vec2(0.999));
	vec2 secondary_crop_source_uv = clamp(
			source_uv + crop_circle_uv_offset(SCREEN_UV, crop_pressed)
					* vec2(-0.72, 1.48),
			vec2(0.001),
			vec2(0.999));
	vec4 source_texel = texture(TEXTURE, source_uv);
	vec4 combed_source = texture(TEXTURE, crop_source_uv);
	vec4 secondary_combed_source = texture(TEXTURE, secondary_crop_source_uv);
	float comb_variation = 0.28 + 0.2 * (
			0.5 + 0.5 * sin(crop_space.x * 8.2 - crop_space.y * 3.4));
	combed_source = mix(combed_source, secondary_combed_source, comb_variation);
	source_texel = mix(source_texel, combed_source, crop_pressed * 0.96);
	vec4 texel = source_texel * COLOR;
	float field_mask = field_band_mask(UV.y) * texel.a;
	float source_highlight = source_highlight_mask(source_texel) * field_mask;
	float moving_wave = moving_wave_mask(UV) * field_mask;
	float wave_enabled = step(0.001, field_wave_strength);
	float resting_highlight = mix(
			1.0,
			field_highlight_rest,
			wave_enabled);
	float removed_highlight = source_highlight
			* (1.0 - resting_highlight)
			* (1.0 - moving_wave);
	texel.rgb *= 1.0 - removed_highlight * field_highlight_demote;
	float migrated_highlight = source_highlight
			* moving_wave
			* field_wave_strength;
	texel.rgb = mix(
			texel.rgb,
			field_wave_color.rgb,
			migrated_highlight * 0.72);
	texel.rgb *= 1.0 + migrated_highlight * 0.16;

	float far_depth_mask = (1.0 - smoothstep(
			field_wave_y_end - 0.02,
			field_wave_y_end + 0.2,
			UV.y)) * texel.a;
	texel.rgb = mix(
			texel.rgb,
			depth_haze_color.rgb,
			far_depth_mask * depth_haze_strength);

	float orientation_light = 0.62 + 0.8 * (
			0.5 + 0.5 * sin(crop_space.x * 3.6 - crop_space.y * 1.8));
	texel.rgb *= mix(1.0, orientation_light, crop_pressed);
	COLOR = texel;
}
