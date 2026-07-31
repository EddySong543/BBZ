shader_type canvas_item;
render_mode unshaded, blend_add;

// Scene1 keeps its moon natural by separating the halo from the moon texture.
// Scene3 follows the same draw-order treatment with a warmer dawn palette.
uniform vec2 sun_screen_pos = vec2(0.51, 0.796);
uniform float viewport_aspect : hint_range(1.0, 2.4, 0.01) = 1.7778;
uniform vec4 core_color : source_color = vec4(1.0, 0.73, 0.45, 1.0);
uniform vec4 corona_color : source_color = vec4(1.0, 0.68, 0.38, 1.0);
uniform vec4 glow_color : source_color = vec4(0.89, 0.63, 0.47, 1.0);
uniform float core_size : hint_range(0.05, 0.4, 0.01) = 0.22;
uniform float corona_size : hint_range(0.1, 0.6, 0.01) = 0.34;
uniform float glow_size : hint_range(0.2, 0.8, 0.01) = 0.52;
uniform float core_intensity : hint_range(0.0, 0.6, 0.01) = 0.2;
uniform float corona_intensity : hint_range(0.0, 0.4, 0.01) = 0.12;
uniform float glow_intensity : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform float flicker_amount : hint_range(0.0, 0.08, 0.005) = 0.015;
uniform float flicker_speed : hint_range(0.0, 2.0, 0.05) = 0.42;
uniform float breath_cycle_sec : hint_range(3.0, 16.0, 0.1) = 7.8;
uniform float breath_amount : hint_range(0.0, 0.2, 0.005) = 0.075;
uniform float corona_drift_speed : hint_range(0.0, 2.0, 0.05) = 0.38;


void fragment() {
	vec2 delta = UV - sun_screen_pos;
	delta.x *= viewport_aspect;
	float distance_to_sun = length(delta);
	float breath_phase = TIME * TAU / max(breath_cycle_sec, 0.001);
	float breath = sin(breath_phase);
	float breathing_distance = distance_to_sun
			/ (1.0 + breath * breath_amount);
	float angle = atan(delta.y, delta.x);
	float corona_wobble = (
			sin(angle * 7.0 + TIME * corona_drift_speed) * 0.035
			+ sin(angle * 3.0 - TIME * corona_drift_speed * 0.61) * 0.025);
	float core = 1.0 - smoothstep(
			core_size * 0.58,
			core_size,
			breathing_distance);
	float corona_outer = 1.0 - smoothstep(
			core_size * 0.74,
			corona_size * (1.0 + corona_wobble),
			breathing_distance);
	float corona_hollow = smoothstep(
			core_size * 0.48,
			core_size * 0.94,
			breathing_distance);
	float corona = corona_outer * mix(0.34, 1.0, corona_hollow);
	float glow = 1.0 - smoothstep(
			core_size * 0.76,
			glow_size,
			breathing_distance);
	float flicker = 1.0
			+ sin(TIME * flicker_speed + 1.2) * flicker_amount;
	float core_light = core * core_intensity;
	float corona_light = corona * corona_intensity;
	float glow_light = glow * glow_intensity;
	float total_light = core_light + corona_light + glow_light;
	float light_alpha = clamp(total_light * flicker, 0.0, 1.0);
	vec3 light_color = (
			glow_color.rgb * glow_light
			+ corona_color.rgb * corona_light
			+ core_color.rgb * core_light) / max(total_light, 0.0001);
	COLOR = vec4(light_color, light_alpha);
}
