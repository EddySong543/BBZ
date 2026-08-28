shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D point_mask : filter_nearest, repeat_disable;
uniform sampler2D cluster_mask : filter_nearest, repeat_disable;
uniform vec4 glow_color : source_color = vec4(0.28, 0.92, 0.75, 1.0);

uniform float point_cycle_sec : hint_range(2.5, 8.0) = 4.8;
uniform float point_time_phase : hint_range(0.0, 1.0) = 0.0;
uniform float animation_seed : hint_range(0.0, 1.0) = 0.5;
uniform float point_cycle_spread : hint_range(0.0, 0.35) = 0.20;
uniform float point_core_base : hint_range(0.0, 0.4) = 0.06;
uniform float point_core_peak : hint_range(0.0, 0.8) = 0.24;
uniform float point_halo_base : hint_range(0.0, 0.2) = 0.015;
uniform float point_halo_peak : hint_range(0.0, 0.5) = 0.12;

uniform float cluster_cycle_sec : hint_range(3.0, 10.0) = 6.2;
uniform float cluster_time_phase : hint_range(0.0, 1.0) = 0.0;
uniform float cluster_core_base : hint_range(0.0, 0.4) = 0.05;
uniform float cluster_core_peak : hint_range(0.0, 0.6) = 0.10;
uniform float cluster_halo_base : hint_range(0.0, 0.2) = 0.015;
uniform float cluster_halo_peak : hint_range(0.0, 0.4) = 0.06;
// Negative keeps normal runtime TIME. Non-negative is used only by the
// non-saving verification probe to sample a complete cycle deterministically.
uniform float diagnostic_time_sec = -1.0;


float hash11(float value) {
	return fract(sin(value) * 43758.5453123);
}


float seeded_pulse_shape(float phase, float fx_time) {
	float local_seed = hash11(phase * 91.731 + animation_seed * 43.117);
	float shape_seed = hash11(phase * 37.913 + animation_seed * 71.231);
	float cycle_scale = mix(
			1.0 - point_cycle_spread,
			1.0 + point_cycle_spread,
			local_seed);
	float local_time = fract(
			fx_time / max(point_cycle_sec * cycle_scale, 0.01)
			+ phase + point_time_phase);
	float rise_end = mix(0.12, 0.23, shape_seed);
	float fall_begin = mix(0.53, 0.70, 1.0 - shape_seed);
	float fall_end = mix(0.84, 0.96, local_seed);
	float rise = smoothstep(0.02, rise_end, local_time);
	float fall = 1.0 - smoothstep(fall_begin, fall_end, local_time);
	return rise * fall;
}


float point_flash(float phase, float fx_time) {
	return seeded_pulse_shape(phase, fx_time);
}


void fragment() {
	vec4 point_data = texture(point_mask, UV);
	vec4 cluster_data = texture(cluster_mask, UV);
	float fx_time = diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
	float flash = point_flash(point_data.b, fx_time);
	vec2 point_texel = 1.0 / vec2(textureSize(point_mask, 0));
	float expanded_point_halo = 0.0;
	expanded_point_halo = max(expanded_point_halo,
			texture(point_mask, UV + vec2(point_texel.x, 0.0)).a);
	expanded_point_halo = max(expanded_point_halo,
			texture(point_mask, UV - vec2(point_texel.x, 0.0)).a);
	expanded_point_halo = max(expanded_point_halo,
			texture(point_mask, UV + vec2(0.0, point_texel.y)).a);
	expanded_point_halo = max(expanded_point_halo,
			texture(point_mask, UV - vec2(0.0, point_texel.y)).a);
	expanded_point_halo *= 1.0 - point_data.a;
	float point_intensity = point_data.a * (point_data.r
			* (point_core_base + point_core_peak * flash)
			+ point_data.g
			* (point_halo_base + point_halo_peak * flash));
	point_intensity += expanded_point_halo * (0.01 + 0.075 * flash);

	float cluster_scale = mix(0.88, 1.12, hash11(animation_seed * 83.17));
	float cluster_phase = fx_time / max(cluster_cycle_sec * cluster_scale, 0.01)
			+ cluster_time_phase + animation_seed * 0.17;
	float breathe = 0.5 + 0.5 * sin(cluster_phase * 6.2831853);
	float cluster_intensity = cluster_data.a * (cluster_data.r
			* (cluster_core_base + cluster_core_peak * breathe)
			+ cluster_data.g
			* (cluster_halo_base + cluster_halo_peak * breathe));

	float intensity = clamp(point_intensity + cluster_intensity, 0.0, 0.86);
	COLOR = vec4(glow_color.rgb, intensity);
}
