shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 virtual_resolution = vec2(480.0, 270.0);
uniform vec2 energy_origin = vec2(0.552, 0.346);
uniform float view_aspect : hint_range(1.0, 2.4, 0.01) = 1.7778;
uniform vec4 navy_color : source_color = vec4(
		0.039216, 0.101961, 0.250980, 0.062);
uniform vec4 gold_color : source_color = vec4(
		0.784314, 0.572549, 0.039216, 0.034);
uniform float drift_pixels : hint_range(0.0, 3.0, 0.1) = 1.5;

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


float stepped_band(float radius, float center, float half_width) {
	return 1.0 - step(half_width, abs(radius - center));
}


float broken_arc(float angular_uv, float sections, float phase) {
	float segment = fract(angular_uv * sections + phase);
	return step(0.20, segment);
}


void fragment() {
	vec2 safe_resolution = max(virtual_resolution, vec2(1.0));
	vec2 pixel_uv = (
			floor(UV * safe_resolution) + vec2(0.5)
		) / safe_resolution;
	vec2 drift = vec2(
			sin(TIME * 0.16),
			cos(TIME * 0.13) * 0.65
		) * drift_pixels / safe_resolution;
	vec2 delta = pixel_uv + drift - energy_origin;
	delta.x *= view_aspect;

	float radius = length(delta);
	float angular_uv = atan(delta.y, delta.x) / 6.2831853 + 0.5;
	float left_window = 1.0 - smoothstep(0.54, 0.78, pixel_uv.x);
	float vertical_window = (
			smoothstep(0.03, 0.12, pixel_uv.y)
			* (1.0 - smoothstep(0.86, 0.98, pixel_uv.y)));

	float ring_one = (
			stepped_band(radius, 0.285, 0.0055)
			* broken_arc(angular_uv, 11.0, 0.12));
	float ring_two = (
			stepped_band(radius, 0.435, 0.0060)
			* broken_arc(angular_uv, 13.0, 0.47));
	float ring_three = (
			stepped_band(radius, 0.605, 0.0065)
			* broken_arc(angular_uv, 15.0, 0.73));
	float ring_four = (
			stepped_band(radius, 0.790, 0.0070)
			* broken_arc(angular_uv, 17.0, 0.31));

	float shared_window = left_window * vertical_window;
	float navy_mask = max(
			max(ring_one, ring_two),
			max(ring_three, ring_four)
		) * shared_window;
	float gold_segments = (
			ring_two
			* step(0.56, fract(angular_uv * 3.0 + 0.18))
			* shared_window);

	vec3 mixed_color = mix(
			navy_color.rgb,
			gold_color.rgb,
			gold_segments);
	float mixed_alpha = max(
			navy_color.a * navy_mask,
			gold_color.a * gold_segments);
	COLOR = vec4(mixed_color, mixed_alpha) * vertex_color;
}
