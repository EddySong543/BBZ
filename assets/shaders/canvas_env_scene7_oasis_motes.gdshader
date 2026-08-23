shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 jade_color : source_color = vec4(0.34, 0.94, 0.69, 1.0);
uniform vec4 gold_color : source_color = vec4(1.0, 0.78, 0.38, 1.0);
uniform vec2 pixel_grid = vec2(960.0, 540.0);
uniform vec2 macro_cell = vec2(112.0, 84.0);
uniform float density : hint_range(0.0, 1.0) = 0.42;
uniform float alpha : hint_range(0.0, 0.6) = 0.32;
uniform float rise_px_per_sec : hint_range(0.0, 8.0) = 3.2;
uniform float horizontal_px_per_sec : hint_range(-4.0, 4.0) = 0.8;
uniform float motion_fps : hint_range(4.0, 20.0) = 12.0;
uniform float twinkle_speed : hint_range(0.0, 2.0) = 0.7;
uniform float phase = 0.0;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	float stepped_time = floor(TIME * motion_fps) / max(motion_fps, 1.0);
	vec2 drift = floor(vec2(
			stepped_time * horizontal_px_per_sec,
			stepped_time * rise_px_per_sec));
	vec2 moving_cell = cell + drift;
	vec2 macro = floor(moving_cell / macro_cell);
	vec2 local_cell = mod(moving_cell, macro_cell);
	float seed_a = hash21(macro + vec2(phase, phase * 1.73));
	float seed_b = hash21(macro * 1.91 + vec2(8.4 + phase, 3.2));
	float seed_c = hash21(macro * 2.37 + vec2(1.7, 9.6 + phase));
	vec2 mote_cell = floor(vec2(
			mix(0.12, 0.88, seed_a) * macro_cell.x,
			mix(0.12, 0.88, seed_b) * macro_cell.y));
	vec2 mote_delta = abs(local_cell - mote_cell);
	float mote = step(max(mote_delta.x, mote_delta.y), 0.1);
	float active = step(1.0 - density, seed_c);
	float vertical_fade = smoothstep(0.0, 0.1, UV.y)
			* (1.0 - smoothstep(0.88, 1.0, UV.y));
	float twinkle = 0.58 + 0.42 * sin(
			TIME * twinkle_speed + seed_a * 6.2831853 + phase);
	vec3 mote_color = mix(jade_color.rgb, gold_color.rgb, step(0.72, seed_b));
	COLOR = vec4(mote_color, mote * active * vertical_fade * alpha * twinkle);
}
