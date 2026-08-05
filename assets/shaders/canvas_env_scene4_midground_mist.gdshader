shader_type canvas_item;
render_mode unshaded, blend_mix;

// A single shallow mist shelf behind the fighters. The field is evaluated on
// the Scene4 pixel grid, so the drift reads as atmosphere rather than blur.
uniform vec4 mist_color : source_color = vec4(0.28, 0.48, 0.39, 1.0);
uniform float mist_strength : hint_range(0.0, 0.2, 0.005) = 0.075;
uniform float drift_speed : hint_range(0.0, 0.04, 0.001) = 0.006;
uniform float band_center : hint_range(0.35, 0.85, 0.01) = 0.64;
uniform float band_half_width : hint_range(0.02, 0.2, 0.01) = 0.085;
uniform vec2 pixel_grid = vec2(240.0, 135.0);

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash21(vec2 value) {
	return fract(
			sin(dot(value, vec2(127.1, 311.7)))
			* 43758.5453);
}


float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 local = fract(value);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


void fragment() {
	vec2 uv = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	float drift = TIME * drift_speed;
	float broad = value_noise(vec2((uv.x + drift) * 5.0, uv.y * 7.0));
	float fine = value_noise(vec2((uv.x - drift * 0.63) * 11.0, uv.y * 13.0));
	float density = smoothstep(0.38, 0.72, broad * 0.72 + fine * 0.28);

	float band = smoothstep(
			band_center - band_half_width,
			band_center - band_half_width * 0.32,
			uv.y);
	band *= 1.0 - smoothstep(
			band_center + band_half_width * 0.28,
			band_center + band_half_width,
			uv.y);
	float edge_breakup = 0.78 + fine * 0.22;
	float alpha = density * band * edge_breakup * mist_strength;
	COLOR = vec4(mist_color.rgb, alpha) * node_modulate;
}
