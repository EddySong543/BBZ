shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 virtual_resolution = vec2(320.0, 180.0);
uniform vec2 energy_origin = vec2(0.552, 0.346);
uniform float view_aspect : hint_range(1.0, 2.4, 0.01) = 1.7778;
uniform float motion_time = 0.0;
uniform float wave_period : hint_range(12.0, 60.0, 0.5) = 44.0;
uniform float wave_spacing : hint_range(0.18, 0.34, 0.005) = 0.285;
uniform float wave_half_width : hint_range(0.012, 0.045, 0.001) = 0.018;
uniform float wave_feather : hint_range(0.006, 0.035, 0.001) = 0.016;
uniform vec4 wave_color : source_color = vec4(
		0.105882, 0.149020, 0.192157, 0.42);
uniform vec2 flow_direction = vec2(-1.0, 0.55);
uniform float direction_spread : hint_range(0.18, 0.70, 0.01) = 0.40;
uniform float right_fade_start : hint_range(0.30, 0.70, 0.01) = 0.44;
uniform float right_fade_end : hint_range(0.40, 0.85, 0.01) = 0.64;
uniform float intro_opacity : hint_range(0.0, 1.0, 0.001) = 1.0;

varying vec4 vertex_color;


float hash_21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	vec2 safe_resolution = max(virtual_resolution, vec2(1.0));
	vec2 pixel_uv = (
			floor(UV * safe_resolution) + vec2(0.5)
		) / safe_resolution;
	vec2 source_delta = pixel_uv - energy_origin;
	vec2 screen_delta = vec2(
			source_delta.x * view_aspect,
			source_delta.y);
	vec2 delta = screen_delta;

	float radius = length(delta);
	vec2 radial_direction = screen_delta / max(
			length(screen_delta),
			0.001);

	// A repeated radial field advances by exactly one spacing per period.
	// The pixel cells only move outward; there is no reverse or breathing.
	float outward_phase = (
			motion_time
			/ max(wave_period, 0.001)
			* wave_spacing);
	float shifted_radius = radius - outward_phase;
	float repeat_phase = (
			fract(
					shifted_radius
					/ max(wave_spacing, 0.001)
					+ 0.5)
			- 0.5);
	float band_distance = abs(repeat_phase) * wave_spacing;

	float core_wave = (
			1.0 - step(wave_half_width, band_distance));
	float edge_progress = (
			(band_distance - wave_half_width)
			/ max(wave_feather, 0.001));
	float edge_zone = (
			step(0.0, edge_progress)
			* (1.0 - step(1.0, edge_progress)));
	vec2 cluster_cell = floor(
			pixel_uv * safe_resolution / vec2(2.0));
	float pixel_edge = (
			edge_zone
			* step(edge_progress, hash_21(cluster_cell)));
	float pixel_wave = max(core_wave, pixel_edge);

	// Reveal only the lower-left fan shared by the gold ring and graphite
	// brush. Adjusting flow_direction rotates the entire pressure field.
	vec2 safe_flow_direction = normalize(
			flow_direction
			+ vec2(0.0001, 0.0001));
	float direction_alignment = dot(
			radial_direction,
			safe_flow_direction);
	float direction_window = smoothstep(
			1.0 - direction_spread,
			1.0 - direction_spread * 0.30,
			direction_alignment);
	float left_window = (
			1.0
			- smoothstep(
					right_fade_start,
					right_fade_end,
					pixel_uv.x));
	float vertical_window = (
			smoothstep(0.08, 0.16, pixel_uv.y)
			* (1.0 - smoothstep(0.76, 0.86, pixel_uv.y)));
	float origin_clear = smoothstep(0.18, 0.28, radius);
	float far_fade = 1.0 - smoothstep(1.00, 1.24, radius);
	float wave_mask = (
			pixel_wave
			* direction_window
			* left_window
			* vertical_window
			* origin_clear
			* far_fade);
	float alpha_steps = 4.0;
	float pixelated_mask = (
			floor(wave_mask * alpha_steps + 0.5)
			/ alpha_steps);

	COLOR = vec4(
			wave_color.rgb,
			wave_color.a
				* pixelated_mask
				* clamp(intro_opacity, 0.0, 1.0)
		) * vertex_color;
}
