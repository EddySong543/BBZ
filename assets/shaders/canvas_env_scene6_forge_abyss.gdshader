shader_type canvas_item;
render_mode unshaded;

// A deep forge chasm beneath the platform: dark rock, sparse vertical molten
// fissures, and heat that travels upward. There is deliberately no liquid
// horizon or horizontal luminous edge.
uniform vec2 size_px = vec2(1984.0, 320.0);
uniform float pixel_size : hint_range(4.0, 8.0, 1.0) = 4.0;
uniform vec4 void_color : source_color = vec4(0.025, 0.004, 0.011, 1.0);
uniform vec4 rock_color : source_color = vec4(0.13, 0.018, 0.028, 1.0);
uniform vec4 ember_color : source_color = vec4(0.62, 0.06, 0.02, 1.0);
uniform vec4 fissure_color : source_color = vec4(0.95, 0.18, 0.025, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.52, 0.10, 1.0);
uniform float fissure_coverage : hint_range(0.02, 0.20, 0.01) = 0.12;
uniform float pulse_cycle_sec : hint_range(5.0, 16.0, 0.1) = 9.6;
uniform float pulse_strength : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float phase_seed : hint_range(0.0, 20.0, 0.1) = 4.7;


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


float vertical_fissure(vec2 px, float column_width) {
	float column = floor(px.x / column_width);
	float active = step(
			1.0 - fissure_coverage,
			hash21(vec2(column, phase_seed + 13.0)));
	float cell_left = column * column_width;
	float base_x = cell_left + mix(
			column_width * 0.22,
			column_width * 0.78,
			hash21(vec2(column, phase_seed + 31.0)));
	float vertical_segment = floor(px.y / 20.0);
	float segment_shift = (hash21(vec2(column, vertical_segment + phase_seed)) - 0.5) * 26.0;
	float previous_shift = (hash21(vec2(column, vertical_segment - 1.0 + phase_seed)) - 0.5) * 26.0;
	float segment_mix = fract(px.y / 20.0);
	float center_x = base_x + mix(previous_shift, segment_shift, segment_mix);
	float distance_x = abs(px.x - center_x);
	float width = pixel_size * mix(
			0.8,
			1.8,
			hash21(vec2(column, vertical_segment + 87.0)));
	float broken = step(
			0.16,
			hash21(vec2(column * 3.1, floor(px.y / 36.0) + phase_seed)));
	return active * broken * (1.0 - step(width, distance_x));
}


float upward_heat_pulse(vec2 px) {
	float travel = TIME / max(pulse_cycle_sec, 0.001);
	float column_phase = hash21(vec2(floor(px.x / 96.0), phase_seed + 71.0));
	float phase = fract(px.y / 124.0 + travel + column_phase * 0.54);
	float main_pulse = 1.0 - smoothstep(0.08, 0.27, abs(phase - 0.34));
	float echo_pulse = 1.0 - smoothstep(0.06, 0.18, abs(phase - 0.78));
	return max(main_pulse, echo_pulse * 0.44);
}


void fragment() {
	vec2 px = floor(UV * size_px / pixel_size) * pixel_size + pixel_size * 0.5;
	float abyss_depth = smoothstep(0.0, 1.0, UV.y);
	float rock_cell = hash21(vec2(floor(px.x / 72.0), floor(px.y / 40.0)));
	float shelf = step(0.55 + abyss_depth * 0.18, rock_cell);
	vec3 color = mix(rock_color.rgb, void_color.rgb, abyss_depth * 0.82);
	color = mix(color, rock_color.rgb * 0.72, shelf * 0.48);

	float fissure = max(
			vertical_fissure(px, 164.0),
			vertical_fissure(px + vec2(71.0, 12.0), 236.0) * 0.72);
	float pulse = upward_heat_pulse(px);
	float lower_furnace = smoothstep(0.48, 1.0, abyss_depth);
	float fissure_energy = fissure * (0.26 + pulse * pulse_strength);
	color = mix(color, ember_color.rgb, fissure * 0.56);
	color = mix(color, fissure_color.rgb, fissure_energy * 0.78);
	color = mix(color, core_color.rgb, fissure * pulse * lower_furnace * 0.24);

	float furnace_glow = lower_furnace
			* (0.065 + hash21(vec2(floor(px.x / 112.0), phase_seed)) * 0.04);
	color += ember_color.rgb * furnace_glow;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
