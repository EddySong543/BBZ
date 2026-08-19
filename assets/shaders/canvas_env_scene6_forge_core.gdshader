shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 size_px = vec2(1664.0, 232.0);
uniform float pixel_size : hint_range(4.0, 8.0, 1.0) = 4.0;
uniform vec4 chamber_color : source_color = vec4(0.22, 0.012, 0.018, 1.0);
uniform vec4 ember_color : source_color = vec4(0.86, 0.07, 0.015, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.39, 0.055, 1.0);
uniform vec4 core_hot_color : source_color = vec4(1.0, 0.73, 0.20, 1.0);
uniform vec4 separator_color : source_color = vec4(0.018, 0.002, 0.007, 1.0);
uniform float core_strength : hint_range(0.0, 1.2, 0.01) = 0.78;
uniform float chamber_coverage : hint_range(0.2, 0.9, 0.01) = 0.68;
uniform float pulse_cycle_sec : hint_range(5.0, 14.0, 0.1) = 7.8;
uniform float phase_seed : hint_range(0.0, 20.0, 0.1) = 8.3;

varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

float furnace_chamber(vec2 px, out float local_x, out float local_y) {
	float chamber_width = 148.0;
	float chamber_id = floor(px.x / chamber_width);
	local_x = mod(px.x, chamber_width) / chamber_width;
	local_y = px.y / max(size_px.y, 1.0);
	float width_jitter = mix(0.18, 0.34, hash21(vec2(chamber_id, phase_seed)));
	float center = 0.5 + (hash21(vec2(chamber_id, phase_seed + 2.7)) - 0.5) * 0.20;
	float side = 1.0 - smoothstep(width_jitter - 0.06, width_jitter, abs(local_x - center));
	float flame_top = mix(0.08, 0.38,
			hash21(vec2(chamber_id, phase_seed + 7.0)));
	float top_arch = smoothstep(
			flame_top + abs(local_x - center) * 0.72,
			flame_top + 0.10 + abs(local_x - center) * 0.72,
			local_y);
	float active = step(1.0 - chamber_coverage,
			hash21(vec2(chamber_id, phase_seed + 11.0)));
	return side * top_arch * active;
}

float rising_core_pulse(vec2 px) {
	float travel = TIME / max(pulse_cycle_sec, 0.001);
	float chamber_phase = hash21(vec2(floor(px.x / 148.0), phase_seed + 31.0));
	float phase = fract(px.y / 116.0 + travel + chamber_phase * 0.46);
	float head = 1.0 - smoothstep(0.06, 0.22, abs(phase - 0.34));
	float tail = 1.0 - smoothstep(0.09, 0.31, abs(phase - 0.55));
	return max(head, tail * 0.42);
}

void fragment() {
	vec2 px = floor(UV * size_px / pixel_size) * pixel_size + pixel_size * 0.5;
	float local_x = 0.0;
	float local_y = 0.0;
	float chamber = furnace_chamber(px, local_x, local_y);
	float chamber_id = floor(px.x / 148.0);
	float separator_seed = hash21(vec2(chamber_id, phase_seed + 51.0));
	float dark_separator = 1.0 - chamber;
	float depth_fade = smoothstep(0.04, 0.22, local_y)
			* (1.0 - smoothstep(0.72, 0.98, local_y));
	float core_distance = abs(local_x - 0.5);
	float core_band = 1.0 - smoothstep(0.08, 0.26, core_distance);
	float pulse = rising_core_pulse(px);
	float broken = step(0.18,
			hash21(vec2(chamber_id * 3.7, floor(px.y / 28.0) + phase_seed)));
	float energy = chamber * depth_fade * broken
			* (0.34 + pulse * core_strength);
	vec3 color = mix(separator_color.rgb, chamber_color.rgb, chamber);
	color = mix(color, ember_color.rgb, energy * 0.70);
	color = mix(color, core_color.rgb, energy * core_band * 0.82);
	color = mix(color, core_hot_color.rgb,
			energy * core_band * pulse * separator_seed * 0.36);
	float edge_ember = chamber * depth_fade * (1.0 - core_band) * 0.28;
	float alpha = max(energy * (0.62 + core_band * 0.30), edge_ember);
	alpha *= 1.0 - dark_separator;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha) * node_modulate;
}
