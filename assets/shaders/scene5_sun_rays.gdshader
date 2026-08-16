shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 sun_center = vec2(0.84, 0.19);
uniform float aspect_ratio : hint_range(1.0, 2.5, 0.001) = 1.777778;
uniform vec4 ray_color : source_color = vec4(1.0, 0.84, 0.46, 1.0);
uniform float ray_intensity : hint_range(0.0, 0.5, 0.01) = 0.17;
uniform float ray_width_scale : hint_range(0.5, 4.0, 0.1) = 2.6;
uniform float drift_amount : hint_range(0.0, 0.15, 0.005) = 0.072;
uniform float gate_speed : hint_range(0.1, 1.5, 0.01) = 0.62;
uniform float breath_cycle_sec : hint_range(3.0, 16.0, 0.1) = 8.4;
uniform vec2 pixel_grid = vec2(480.0, 270.0);


float sun_shaft(
		vec2 point,
		vec2 direction,
		float base_width,
		float spread,
		float max_length,
		float phase) {
	float along = dot(point, direction);
	float across = abs(dot(point, vec2(-direction.y, direction.x)));
	float width = base_width + max(along, 0.0) * spread;
	float body = 1.0 - smoothstep(width * 0.48, width, across);
	float forward = smoothstep(-0.01, 0.045, along);
	float end_fade = 1.0 - smoothstep(max_length * 0.58, max_length, along);
	float broken = 0.76 + sin(
			along * 38.0
			- TIME * 0.34
			+ phase) * 0.12;
	return body * forward * end_fade * broken;
}


vec2 rotate_direction(vec2 direction, float angle) {
	float cosine = cos(angle);
	float sine = sin(angle);
	return vec2(
			direction.x * cosine - direction.y * sine,
			direction.x * sine + direction.y * cosine);
}


float slow_gate(float time_value, float phase, float floor_value) {
	float wave = 0.5 + 0.5 * sin(time_value + phase);
	float opened = smoothstep(0.24, 0.76, wave);
	return mix(floor_value, 1.0, opened);
}


void fragment() {
	vec2 snapped_uv = floor(UV * pixel_grid + 0.5) / pixel_grid;
	vec2 point = snapped_uv - sun_center;
	point.x *= aspect_ratio;
	float breath = 0.88 + sin(
			TIME * TAU / max(breath_cycle_sec, 0.001)) * 0.12;
	float drift = sin(TIME * 0.24) * drift_amount;
	float gate_time = TIME * gate_speed;

	float shafts = 0.0;
	shafts += sun_shaft(point, rotate_direction(normalize(vec2(-0.96, 0.29)), drift), 0.014 * ray_width_scale, 0.041 * ray_width_scale, 1.16, 0.4)
			* slow_gate(gate_time, 0.1, 0.08) * 0.76;
	shafts += sun_shaft(point, rotate_direction(normalize(vec2(-0.72, 0.69)), drift * 0.72), 0.018 * ray_width_scale, 0.047 * ray_width_scale, 1.1, 2.1)
			* slow_gate(gate_time, 1.45, 0.12);
	shafts += sun_shaft(point, rotate_direction(normalize(vec2(-0.43, 0.9)), -drift * 0.55), 0.016 * ray_width_scale, 0.044 * ray_width_scale, 0.96, 4.3)
			* slow_gate(gate_time, 2.75, 0.06) * 0.9;
	shafts += sun_shaft(point, rotate_direction(normalize(vec2(-0.12, 0.99)), -drift * 0.9), 0.012 * ray_width_scale, 0.035 * ray_width_scale, 0.78, 5.4)
			* slow_gate(gate_time, 4.15, 0.04) * 0.66;
	float source_fade = smoothstep(0.045, 0.13, length(point));
	float horizon_fade = 1.0 - smoothstep(0.76, 1.04, snapped_uv.y);
	float alpha = clamp(
			shafts * source_fade * horizon_fade * ray_intensity * breath,
			0.0,
			0.22);
	COLOR = vec4(ray_color.rgb, alpha);
}
