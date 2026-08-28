shader_type canvas_item;
render_mode unshaded, blend_mix;

// Current-vision shadow only. It never samples exploration history and never
// replaces terrain: distant geography remains readable through the outer veil.
uniform vec2 world_size_px = vec2(3840.0, 2160.0);
uniform vec2 player_world_px = vec2(1920.0, 1080.0);
uniform float cell_px = 120.0;
uniform float inner_radius_cells : hint_range(1.0, 6.0) = 2.5;
uniform float outer_radius_cells : hint_range(2.0, 9.0) = 4.5;
uniform float horizontal_ratio : hint_range(1.0, 2.0) = 1.4;
uniform float outer_alpha : hint_range(0.0, 0.8) = 0.60;
uniform float edge_irregularity_cells : hint_range(0.0, 1.0) = 0.42;
uniform float seed_f = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.018, 0.064, 0.055, 1.0);


float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}


float value_noise(vec2 position) {
	vec2 base = floor(position);
	vec2 local = fract(position);
	vec2 blend = local * local * (vec2(3.0) - 2.0 * local);
	float top = mix(hash21(base), hash21(base + vec2(1.0, 0.0)), blend.x);
	float bottom = mix(
			hash21(base + vec2(0.0, 1.0)),
			hash21(base + vec2(1.0, 1.0)), blend.x);
	return mix(top, bottom, blend.y);
}


void fragment() {
	vec2 world_px = UV * world_size_px;
	vec2 delta_cells = (world_px - player_world_px) / cell_px;
	vec2 shaped_delta = vec2(delta_cells.x / horizontal_ratio, delta_cells.y);
	float superellipse_distance = pow(
			pow(abs(shaped_delta.x), 4.0) + pow(abs(shaped_delta.y), 4.0), 0.25);
	vec2 noise_position = world_px / cell_px * 0.19 + vec2(seed_f * 0.013);
	float broad_noise = value_noise(noise_position) - 0.5;
	float edge_shift = broad_noise * edge_irregularity_cells;
	float shadow_amount = smoothstep(
			inner_radius_cells + edge_shift * 0.25,
			outer_radius_cells + edge_shift,
			superellipse_distance);
	float outer_variation = mix(0.94, 1.0, value_noise(noise_position * 0.53 + vec2(7.1)));
	COLOR = vec4(shadow_color.rgb, shadow_amount * outer_alpha * outer_variation);
}
