shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 ray_color : source_color = vec4(0.74, 0.72, 0.66, 1.0);
uniform vec4 core_color : source_color = vec4(0.98, 0.82, 0.58, 1.0);
uniform float ray_intensity : hint_range(0.0, 1.5, 0.01) = 0.36;
uniform vec2 pixel_grid = vec2(480.0, 144.0);
uniform vec2 hidden_sun_center = vec2(0.52, 1.06);
uniform float cloud_line_y : hint_range(0.70, 1.0, 0.01) = 0.88;
uniform float shaft_width_scale : hint_range(1.0, 4.0, 0.1) = 2.6;
uniform float inner_feather_px : hint_range(2.0, 16.0, 0.5) = 7.0;
uniform float outer_feather_px : hint_range(6.0, 32.0, 0.5) = 18.0;
uniform float source_drift : hint_range(0.0, 0.03, 0.001) = 0.004;

// Match CloudSeaMid so rolling cloud lobes reveal each candidate shaft.
uniform float cloud_roll_speed = 0.42;
uniform float cloud_billow_speed = 0.82;
uniform float cloud_roll_phase = 2.1;
uniform float cloud_billow_phase = 1.7;


vec2 semicircle_direction(float angle_radians) {
	return normalize(vec2(cos(angle_radians), -sin(angle_radians)));
}


float cloud_gap_opening(float shaft_id, float source_x) {
	float roll = sin(
			TIME * cloud_roll_speed
			+ cloud_roll_phase
			+ source_x * 8.3
			+ shaft_id * 1.11);
	float fold = sin(
			-TIME * cloud_roll_speed * 1.37
			+ cloud_roll_phase * 1.7
			+ source_x * 13.1
			- shaft_id * 0.73);
	float billow = sin(
			TIME * cloud_billow_speed
			+ cloud_billow_phase
			+ source_x * 5.7
			+ shaft_id * 0.41);
	float cloud_gap = roll * 0.44 + fold * 0.20 + billow * 0.36;
	float threshold = -0.16 + fract(shaft_id * 0.6180339) * 0.14;
	return smoothstep(threshold - 0.20, threshold + 0.42, cloud_gap);
}


vec2 rising_shaft(
		vec2 uv,
		float shaft_id,
		float angle_radians,
		float base_width,
		float upper_spread,
		float top_y,
		float strength) {
	vec2 direction = semicircle_direction(angle_radians);
	float cloud_travel = (cloud_line_y - hidden_sun_center.y) / direction.y;
	float source_x = hidden_sun_center.x + direction.x * cloud_travel;
	float opening = cloud_gap_opening(shaft_id, source_x);

	float drift_wave = sin(
			TIME * cloud_roll_speed * 0.72
			+ cloud_roll_phase
			+ shaft_id * 1.83);
	float drift = floor(
			drift_wave * source_drift * pixel_grid.x + 0.5
	) / pixel_grid.x;
	vec2 local_uv = uv - vec2(drift, 0.0);
	vec2 from_sun = local_uv - hidden_sun_center;
	float along = dot(from_sun, direction);
	float across = abs(dot(from_sun, vec2(-direction.y, direction.x)));
	float visible_rise = cloud_line_y - uv.y;
	float height_ratio = clamp(
			visible_rise / max(cloud_line_y - top_y, 0.001),
			0.0,
			1.0);

	float width = (base_width + upper_spread * height_ratio)
			* shaft_width_scale;
	width *= mix(0.90, 1.08, opening);
	float inner_feather = inner_feather_px / pixel_grid.x;
	float outer_feather = outer_feather_px / pixel_grid.x;
	float inner_body = 1.0 - smoothstep(
			width * 0.72,
			width * 0.72 + inner_feather,
			across);
	float outer_bloom = 1.0 - smoothstep(
			width,
			width + outer_feather,
			across);
	float soft_body = inner_body * 0.50 + outer_bloom * 0.50;

	float emerge = smoothstep(0.045, 0.14, visible_rise);
	float upper_fade = smoothstep(top_y, top_y + 0.30, uv.y);
	float altitude_fade = mix(1.0, 0.62, height_ratio);
	float forward = smoothstep(0.0, 0.08, along);
	float alpha = soft_body * emerge * upper_fade * altitude_fade
			* forward * opening * strength;
	return vec2(alpha, inner_body * opening * strength);
}


void fragment() {
	vec2 uvq = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;

	vec2 ray_far_right = rising_shaft(
			uvq, 0.35, 0.84, 0.0060, 0.0110, 0.22, 0.62);
	vec2 ray_right = rising_shaft(
			uvq, 1.40, 1.08, 0.0075, 0.0140, 0.15, 0.78);
	vec2 ray_mid_right = rising_shaft(
			uvq, 2.55, 1.34, 0.0080, 0.0150, 0.11, 0.88);
	vec2 ray_mid_left = rising_shaft(
			uvq, 3.70, 1.71, 0.0075, 0.0140, 0.12, 0.84);
	vec2 ray_left = rising_shaft(
			uvq, 4.85, 2.02, 0.0070, 0.0130, 0.16, 0.74);
	vec2 ray_far_left = rising_shaft(
			uvq, 6.05, 2.30, 0.0055, 0.0100, 0.23, 0.58);
	vec2 shafts = clamp(
			ray_far_right + ray_right + ray_mid_right
			+ ray_mid_left + ray_left + ray_far_left,
			vec2(0.0),
			vec2(1.0));

	float root_warmth = smoothstep(0.42, cloud_line_y, uvq.y);
	float core_mix = clamp(root_warmth * 0.72 + shafts.y * 0.18, 0.0, 0.82);
	vec3 color = mix(ray_color.rgb, core_color.rgb, core_mix);
	float alpha = clamp(shafts.x * ray_intensity, 0.0, 0.42);
	COLOR = vec4(color, alpha);
}
