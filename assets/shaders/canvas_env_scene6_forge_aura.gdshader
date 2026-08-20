shader_type canvas_item;
render_mode unshaded, blend_add;

// A low-resolution furnace mist, not a geometric beam. Its carrier fades to
// zero on every edge; value noise only changes density inside that soft field.
uniform vec2 size_px = vec2(240.0, 176.0);
uniform float pixel_px : hint_range(2.0, 6.0, 1.0) = 4.0;
uniform float presence : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float seed = 0.0;
uniform float flow_speed : hint_range(0.0, 0.4, 0.01) = 0.11;
uniform vec4 ember_color : source_color = vec4(0.92, 0.18, 0.025, 1.0);
uniform vec4 gold_color : source_color = vec4(1.0, 0.58, 0.10, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.76, 0.24, 1.0);

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


void fragment() {
	// Keep the atmosphere in the scene's authored pixel scale while its
	// density changes continuously between those fixed spatial cells.
	vec2 point_px = (floor(UV * size_px / pixel_px) + vec2(0.5)) * pixel_px;
	vec2 uv = point_px / size_px;
	float height = 1.0 - uv.y;
	float clock = TIME * flow_speed;

	float center_noise = value_noise(vec2(
			height * 2.8 + seed * 0.017,
			clock * 0.34 + seed * 0.071));
	float center_shift = (center_noise - 0.5) * mix(0.025, 0.075, height);
	float half_width = mix(0.225, 0.435, smoothstep(0.0, 1.0, height));
	float across = abs(uv.x - 0.5 - center_shift) / max(half_width, 0.001);

	float edge_noise = value_noise(vec2(
			uv.y * 5.6 - clock * 0.27,
			seed * 0.11 + height * 1.7));
	edge_noise += value_noise(vec2(
			uv.y * 11.0 + seed * 0.043,
			clock * 0.19 + 7.3)) * 0.5;
	edge_noise = edge_noise / 1.5;
	float irregular_edge = (edge_noise - 0.5) * mix(0.12, 0.26, height);
	float field = 1.0 - smoothstep(
			0.48 + irregular_edge,
			1.02 + irregular_edge,
			across);

	float flow_a = value_noise(vec2(
			uv.x * 5.2 + seed * 0.031,
			uv.y * 6.4 + clock * 0.62));
	float flow_b = value_noise(vec2(
			uv.x * 10.3 - clock * 0.18,
			uv.y * 3.7 + seed * 0.053 + clock * 0.31));
	float density = mix(0.48, 1.0, flow_a * 0.62 + flow_b * 0.38);
	float interior = field * density;

	// Fade every carrier boundary before it can reveal the ColorRect. The
	// bottom extends eight pixels into the lake, so the visible surface lands
	// inside the bright part of the field instead of at a cut edge.
	float vertical_fade = smoothstep(0.015, 0.20, uv.y)
			* (1.0 - smoothstep(0.955, 1.0, uv.y));
	float source_x = abs(uv.x - 0.5 - center_shift * 0.25);
	float source_y = abs(uv.y - 0.945);
	float source_bloom = (1.0 - smoothstep(0.08, 0.34, source_x))
			* (1.0 - smoothstep(0.012, 0.085, source_y));
	source_bloom *= mix(0.70, 1.0, edge_noise);

	float core = (1.0 - smoothstep(0.08, 0.64, across))
			* mix(0.40, 1.0, flow_b);
	float lower_heat = smoothstep(0.28, 0.96, uv.y);
	vec3 light_color = mix(ember_color.rgb, gold_color.rgb,
			0.28 + lower_heat * 0.50);
	light_color = mix(light_color, core_color.rgb,
			clamp(source_bloom * 0.72 + core * lower_heat * 0.16, 0.0, 0.62));

	float alpha = interior * vertical_fade * mix(0.075, 0.18, lower_heat);
	alpha += source_bloom * 0.14;
	alpha *= presence;
	COLOR = vec4(light_color, clamp(alpha, 0.0, 0.28)) * node_modulate;
}
