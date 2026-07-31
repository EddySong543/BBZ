shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glint_color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.72, 1.0);
uniform float cycle_sec : hint_range(8.0, 14.0, 0.25) = 9.5;
uniform float phase_offset : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float pulse_hold : hint_range(0.04, 0.14, 0.005) = 0.09;
uniform float pulse_fade : hint_range(0.01, 0.06, 0.005) = 0.03;
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform vec2 pixel_grid = vec2(16.0, 16.0);
uniform float core_radius_px : hint_range(0.5, 2.5, 0.5) = 1.0;
uniform float arm_length_px : hint_range(2.0, 7.0, 0.5) = 4.5;


void fragment() {
	vec2 pixel = floor(UV * pixel_grid) + vec2(0.5);
	vec2 center = pixel_grid * 0.5;
	vec2 delta = pixel - center;
	float cycle_position = fract(TIME / cycle_sec + phase_offset);
	float pulse_in = smoothstep(0.0, pulse_fade, cycle_position);
	float pulse_out = 1.0 - smoothstep(
			pulse_hold,
			pulse_hold + pulse_fade,
			cycle_position);
	float pulse = pulse_in * pulse_out;

	float diamond_distance = abs(delta.x) + abs(delta.y);
	float core = 1.0 - step(core_radius_px + 0.5, diamond_distance);
	float horizontal = (
			1.0 - step(0.75, abs(delta.y))
	) * (
			1.0 - step(arm_length_px + 0.5, abs(delta.x))
	);
	float vertical = (
			1.0 - step(0.75, abs(delta.x))
	) * (
			1.0 - step(arm_length_px + 0.5, abs(delta.y))
	);
	float arm_falloff = clamp(
			1.0 - max(abs(delta.x), abs(delta.y))
					/ max(arm_length_px, 0.001),
			0.0,
			1.0);
	float shape = max(core, max(horizontal, vertical) * arm_falloff);
	vec3 color = mix(glint_color.rgb, core_color.rgb, core);
	float alpha = shape * pulse * intensity;
	COLOR = vec4(color, alpha);
}
