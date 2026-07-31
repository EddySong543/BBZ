shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 fog_color : source_color = vec4(0.66, 0.75, 0.76, 0.36);
uniform float strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float flow_speed : hint_range(-1.0, 1.0, 0.01) = 0.05;
uniform float pixel_size : hint_range(1.0, 12.0, 1.0) = 4.0;

float hash(vec2 p) {
	p = fract(p * vec2(43.17, 91.73));
	p += dot(p, p + 17.17);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 grid = floor(UV * vec2(480.0 / pixel_size, 270.0 / pixel_size))
			/ vec2(480.0 / pixel_size, 270.0 / pixel_size);
	float band = smoothstep(0.08, 0.34, grid.y) * (1.0 - smoothstep(0.70, 1.0, grid.y));
	float curls = sin((grid.x + TIME * flow_speed) * 18.0 + sin(grid.y * 16.0) * 2.0) * 0.5 + 0.5;
	float broken = hash(floor(vec2(grid.x * 64.0, grid.y * 20.0)));
	float mask = band * smoothstep(0.28, 0.88, curls) * smoothstep(0.18, 0.62, broken);
	COLOR = vec4(fog_color.rgb, fog_color.a * mask * strength);
}
