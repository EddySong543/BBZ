shader_type canvas_item;
render_mode unshaded, blend_add;

// Both the broad canopy dust and the four small relic fields follow the same
// canopy rhythm. Relic fields add a second gate matching each stone's energy
// phase, so they strengthen briefly without becoming permanent spark showers.
uniform float base_visibility : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float shaft_response : hint_range(0.0, 1.0, 0.01) = 0.76;
uniform float relic_response : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float relic_pulse_speed : hint_range(0.0, 0.2, 0.005) = 0.09;
uniform float relic_pulse_phase : hint_range(0.0, 6.3, 0.01) = 0.0;
uniform vec4 mote_tint : source_color = vec4(0.82, 0.94, 0.72, 1.0);


float slow_gate(float time_value, float phase, float floor_value) {
	float wave = 0.5 + 0.5 * sin(time_value + phase);
	float opened = smoothstep(0.24, 0.76, wave);
	return mix(floor_value, 1.0, opened);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 particle_modulate = COLOR;
	float gate_time = TIME * 0.62;
	float shaft_activity = (
			slow_gate(gate_time, 0.1, 0.0) * 0.66
			+ slow_gate(gate_time, 1.45, 0.0)
			+ slow_gate(gate_time, 2.75, 0.04) * 0.92
			+ slow_gate(gate_time, 4.15, 0.0) * 0.82
			+ slow_gate(gate_time, 5.35, 0.0) * 0.68
	) / 4.08;
	shaft_activity = smoothstep(0.28, 0.72, shaft_activity);

	float relic_head = fract(
			TIME * relic_pulse_speed
			+ relic_pulse_phase / 6.2831);
	float relic_active = smoothstep(0.08, 0.28, relic_head)
			* (1.0 - smoothstep(0.66, 0.9, relic_head));
	float visibility = mix(
			base_visibility,
			1.0,
			shaft_activity * shaft_response);
	visibility *= mix(1.0, mix(0.28, 1.0, relic_active), relic_response);

	COLOR = source * particle_modulate
			* vec4(mote_tint.rgb, mote_tint.a * visibility);
}
