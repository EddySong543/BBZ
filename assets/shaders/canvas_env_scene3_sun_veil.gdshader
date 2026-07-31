shader_type canvas_item;
render_mode unshaded, blend_mix;

// A localized horizon veil drawn in front of the sun disc. It carries the
// lower-sky color through the disc so the sun reads inside the atmosphere.
uniform vec2 veil_center = vec2(0.51, 0.765);
uniform vec2 veil_radius = vec2(0.36, 0.145);
uniform vec4 veil_color : source_color = vec4(0.89, 0.68, 0.58, 1.0);
uniform float veil_strength : hint_range(0.0, 0.5, 0.01) = 0.22;
uniform float flow_speed : hint_range(-0.1, 0.1, 0.005) = 0.015;
uniform vec2 pixel_grid = vec2(480.0, 270.0);


void fragment() {
	vec2 suv = (floor(SCREEN_UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	vec2 delta = (suv - veil_center) / max(veil_radius, vec2(0.001));
	float horizontal = 1.0 - smoothstep(0.58, 1.0, abs(delta.x));
	float vertical = 1.0 - smoothstep(0.42, 1.0, abs(delta.y));
	float broad_roll = sin(
			suv.x * 18.0 + TIME * flow_speed * TAU) * 0.5 + 0.5;
	float fine_roll = sin(
			suv.x * 43.0 - TIME * flow_speed * TAU * 0.73 + 1.7)
			* 0.5 + 0.5;
	float broken_density = 0.78 + broad_roll * 0.14 + fine_roll * 0.08;
	float lower_bias = smoothstep(
			veil_center.y - veil_radius.y,
			veil_center.y + veil_radius.y * 0.72,
			suv.y);
	float veil_band = horizontal * vertical
			* mix(0.72, 1.0, lower_bias)
			* broken_density;
	COLOR = vec4(
			veil_color.rgb,
			clamp(veil_band * veil_strength, 0.0, 1.0));
}
