shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D flow_texture : repeat_disable, filter_nearest;
uniform float motion_time = 0.0;
uniform float flow_period : hint_range(2.0, 12.0, 0.1) = 5.2;
uniform float hand_flow_pixels : hint_range(0.0, 8.0, 0.1) = 2.5;
uniform float escape_flow_pixels : hint_range(0.0, 16.0, 0.5) = 4.0;

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


float hand_region(float flow_region) {
	return 1.0 - smoothstep(0.05, 0.14, abs(flow_region - 0.35));
}


float escape_region(float flow_region) {
	return smoothstep(0.72, 0.96, flow_region);
}


float phase_weight(float phase) {
	return 1.0 - abs(phase * 2.0 - 1.0);
}


void fragment() {
	vec4 flow = texture(flow_texture, UV);
	vec2 direction = flow.rg * 2.0 - 1.0;
	float direction_length = length(direction);
	direction = direction_length > 0.001
			? direction / direction_length
			: vec2(0.0);

	float hand_mask = hand_region(flow.b);
	float escape_mask = escape_region(flow.b);
	float flow_mask = max(hand_mask, escape_mask);
	float travel_pixels = (
			hand_mask * hand_flow_pixels
			+ escape_mask * escape_flow_pixels);

	// Each phase only advances in the encoded upper-right direction.
	// Its reset happens at zero weight while the other phase carries the
	// texture, so the energy never visibly reverses or globally breathes.
	float clock = (
			motion_time / max(flow_period, 0.001)
			+ flow.a * 0.08);
	float phase_a = fract(clock);
	float phase_b = fract(clock + 0.5);
	float weight_a = phase_weight(phase_a);
	float weight_b = phase_weight(phase_b);
	float weight_sum = max(weight_a + weight_b, 0.001);

	vec2 offset_a = (
			direction
			* phase_a
			* travel_pixels
			* TEXTURE_PIXEL_SIZE);
	vec2 offset_b = (
			direction
			* phase_b
			* travel_pixels
			* TEXTURE_PIXEL_SIZE);
	vec4 sample_a = texture(
			TEXTURE,
			clamp(UV - offset_a, vec2(0.0), vec2(1.0)));
	vec4 sample_b = texture(
			TEXTURE,
			clamp(UV - offset_b, vec2(0.0), vec2(1.0)));

	vec3 transported_rgb = (
			sample_a.rgb * sample_a.a * weight_a
			+ sample_b.rgb * sample_b.a * weight_b
			) / max(
					sample_a.a * weight_a
					+ sample_b.a * weight_b,
					0.001);
	float transported_alpha = (
			sample_a.a * weight_a
			+ sample_b.a * weight_b
			) / weight_sum;
	vec4 transported = vec4(
			transported_rgb,
			transported_alpha);
	vec4 source = texture(TEXTURE, UV);

	COLOR = mix(source, transported, flow_mask) * vertex_color;
}
