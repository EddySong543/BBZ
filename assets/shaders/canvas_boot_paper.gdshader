shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 paper_color : source_color = vec4(
		0.105882, 0.164706, 0.254902, 1.0);
uniform float fine_grain_strength : hint_range(0.0, 0.05, 0.001) = 0.010;
uniform float broad_grain_strength : hint_range(0.0, 0.05, 0.001) = 0.014;
uniform vec2 grain_cells = vec2(480.0, 270.0);

varying vec4 vertex_color;


float hash_21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float a = hash_21(cell);
	float b = hash_21(cell + vec2(1.0, 0.0));
	float c = hash_21(cell + vec2(0.0, 1.0));
	float d = hash_21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}


void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	float fine_grain = hash_21(floor(UV * grain_cells)) - 0.5;
	float broad_grain = value_noise(UV * vec2(13.0, 8.0)) - 0.5;
	float fibers = (
			sin(UV.x * 930.0 + UV.y * 170.0)
			* sin(UV.y * 760.0 - UV.x * 90.0)
			* 0.25);
	float variation = (
			fine_grain * fine_grain_strength
			+ broad_grain * broad_grain_strength
			+ fibers * fine_grain_strength);
	vec3 paper = clamp(
			paper_color.rgb + vec3(variation),
			vec3(0.0),
			vec3(1.0));
	COLOR = vec4(paper, paper_color.a) * vertex_color;
}
