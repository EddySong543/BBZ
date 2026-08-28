shader_type canvas_item;
render_mode unshaded, blend_mix;

// Portal-only version of the retired horizontal wave curtain. The same
// quantized energy body now covers and reveals from screen bottom to top.
uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform float aspect = 1.777;
uniform float cells_y = 36.0;
uniform float wave_amp = 0.07;
uniform float wave_time = 0.0;
uniform vec3 deep_color : source_color = vec3(0.10, 0.22, 0.48);
uniform vec3 crest_color : source_color = vec3(0.36, 0.64, 1.0);
uniform float levels = 7.0;
uniform float body_min = 0.15;
uniform float body_max = 0.88;

const int BODY_WAVES = 5;
const float K_CORE = 4200.0;
const float K_SHEATH = 260.0;
const float BODY_FLOW = 0.30;
const float CORE_TOP = 0.90;
const float CRACKLE_HZ = 6.0;
const float CRACKLE_AMP = 0.007;
const float FLOW_DENSITY = 0.30;
const float FLOW_LEN = 0.06;
const float FLOW_BRIGHT = 0.55;
const float DEAD = 0.06;


float dz(float value) {
	return max(value - DEAD, 0.0) / (1.0 - DEAD);
}


float hash11(float value) {
	return fract(sin(value) * 43758.5453);
}


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}


float edge_wave(float x, float time_value, float seed) {
	return sin(x * 16.0 * aspect + time_value * 3.1 + seed) * 0.55
			+ sin(x * 6.3 * aspect - time_value * 2.2 + seed * 1.7) * 0.45;
}


void fragment() {
	vec2 cell = vec2(max(cells_y * aspect, 1.0), cells_y);
	vec2 uv = (floor(UV * cell) + 0.5) / cell;
	float yp = 1.0 - uv.y;
	float span = 1.0 + 2.0 * wave_amp;
	float front = min(progress, 1.0) * span - wave_amp
			+ edge_wave(uv.x, wave_time, 0.0) * wave_amp;
	float back = max(progress - 1.0, 0.0) * span - wave_amp
			+ edge_wave(uv.x, wave_time, 5.0) * wave_amp;
	float inside = step(yp, front) * step(back, yp);

	float column = floor(uv.x * cell.x);
	float time_step = floor(wave_time * CRACKLE_HZ);
	float jitter = (hash21(vec2(column, time_step)) - 0.5) * CRACKLE_AMP;
	float core_acc = 0.0;
	float sheath_acc = 0.0;
	for (int index = 0; index < BODY_WAVES; index++) {
		float cycle = fract(wave_time * BODY_FLOW
				+ float(index) / float(BODY_WAVES));
		float position = mix(-0.10, 1.10, cycle);
		float envelope = smoothstep(0.0, 0.08, cycle)
				* (1.0 - smoothstep(0.88, 1.0, cycle));
		float distance_value = yp - position + jitter;
		core_acc = max(core_acc,
				dz(exp(-distance_value * distance_value * K_CORE)) * envelope);
		sheath_acc = max(sheath_acc,
				dz(exp(-distance_value * distance_value * K_SHEATH))
				* step(distance_value, 0.0) * envelope);
	}

	float active = step(hash11(column * 7.31 + 3.0), FLOW_DENSITY);
	float speed = 0.35 + 0.30 * hash11(column * 3.17 + 8.0);
	float flow_progress = fract(
			wave_time * speed + hash11(column * 9.13 + 13.0));
	float flow_position = mix(-0.05, 1.05, flow_progress);
	float flow_distance = yp - flow_position;
	float streak = active * step(-FLOW_LEN, flow_distance)
			* step(flow_distance, 0.0) * (1.0 + flow_distance / FLOW_LEN)
			* smoothstep(0.02, 0.10, flow_progress)
			* (1.0 - smoothstep(0.85, 1.0, flow_progress));
	float brightness_span = body_max - body_min;
	float body_texture = max(sheath_acc * 0.85, streak * FLOW_BRIGHT);
	float brightness = body_min
			+ max(body_texture, core_acc * CORE_TOP) * brightness_span;

	float front_distance = clamp((front - yp) / 0.16, 0.0, 1.0);
	float back_distance = clamp((yp - back) / 0.16, 0.0, 1.0);
	float crest_glow = max(1.0 - front_distance, 1.0 - back_distance);
	brightness = mix(brightness, 1.0, crest_glow);
	brightness = floor(brightness * levels + 0.5) / levels;
	vec3 color_value = mix(deep_color, crest_color, brightness);
	float tip = max(step(front - yp, 0.022), step(yp - back, 0.022));
	color_value = mix(color_value, vec3(0.95, 0.97, 1.0), tip * 0.55);
	COLOR = vec4(color_value, inside);
}
