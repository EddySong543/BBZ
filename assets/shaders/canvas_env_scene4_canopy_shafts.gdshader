shader_type canvas_item;
render_mode unshaded, blend_add;

// Pixel-stepped canopy gaps alternate slowly instead of staying permanently
// lit. Each shaft owns a different phase, so several shafts can overlap while
// the overall composition still keeps opening and closing.
uniform vec4 beam_color : source_color = vec4(0.48, 0.86, 0.58, 1.0);
uniform float beam_strength : hint_range(0.0, 0.4, 0.005) = 0.18;
uniform float sway_amount : hint_range(0.0, 0.04, 0.001) = 0.008;
uniform float sway_speed : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform vec2 pixel_grid = vec2(240.0, 135.0);

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float beam(vec2 uv, float center, float width) {
	float diagonal_x = uv.x + (1.0 - uv.y) * 0.13;
	return 1.0 - smoothstep(
			width,
			width + 0.018,
			abs(diagonal_x - center));
}


float slow_gate(float time_value, float phase, float floor_value) {
	float wave = 0.5 + 0.5 * sin(time_value + phase);
	float opened = smoothstep(0.24, 0.76, wave);
	return mix(floor_value, 1.0, opened);
}


void fragment() {
	vec2 uv = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	float sway = sin(TIME * sway_speed) * sway_amount;
	float gate_time = TIME * 0.62;
	float shafts = beam(uv, 0.17 + sway * 0.55, 0.022)
			* slow_gate(gate_time, 0.1, 0.0) * 0.66;
	shafts += beam(uv, 0.33 + sway, 0.034)
			* slow_gate(gate_time, 1.45, 0.0);
	shafts += beam(uv, 0.52 - sway * 0.72, 0.046)
			* slow_gate(gate_time, 2.75, 0.04) * 0.92;
	shafts += beam(uv, 0.70 + sway * 0.42, 0.031)
			* slow_gate(gate_time, 4.15, 0.0) * 0.82;
	shafts += beam(uv, 0.86 - sway * 0.60, 0.024)
			* slow_gate(gate_time, 5.35, 0.0) * 0.68;

	float vertical_fade = smoothstep(0.035, 0.16, uv.y)
			* (1.0 - smoothstep(0.58, 0.76, uv.y));
	float breath = 0.78 + 0.22 * sin(TIME * 0.34 + 1.2);
	float alpha = clamp(
			shafts * vertical_fade * beam_strength * breath,
			0.0,
			0.32);
	COLOR = vec4(beam_color.rgb, alpha) * node_modulate;
}
