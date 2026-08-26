shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D point_mask : filter_nearest;
uniform sampler2D cluster_mask : filter_nearest;
uniform vec4 glow_color : source_color = vec4(0.28, 0.92, 0.75, 1.0);

uniform float point_cycle_sec : hint_range(2.5, 8.0) = 4.8;
uniform float point_time_phase : hint_range(0.0, 1.0) = 0.0;
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


float point_flash(float phase, float fx_time) {
	float local_time = fract(
			fx_time / max(point_cycle_sec, 0.01) + phase + point_time_phase);
	float rise = smoothstep(0.05, 0.11, local_time);
	float fall = 1.0 - smoothstep(0.23, 0.38, local_time);
	return rise * fall;
}


void fragment() {
	vec4 point_data = texture(point_mask, UV);
	vec4 cluster_data = texture(cluster_mask, UV);
	float fx_time = diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
	float flash = point_flash(point_data.b, fx_time);
	float point_intensity = point_data.a * (point_data.r
			* (point_core_base + point_core_peak * flash)
			+ point_data.g
			* (point_halo_base + point_halo_peak * flash));

	float cluster_phase = fx_time / max(cluster_cycle_sec, 0.01)
			+ cluster_time_phase;
	float breathe = 0.5 + 0.5 * sin(cluster_phase * 6.2831853);
	float cluster_intensity = cluster_data.a * (cluster_data.r
			* (cluster_core_base + cluster_core_peak * breathe)
			+ cluster_data.g
			* (cluster_halo_base + cluster_halo_peak * breathe));

	float intensity = clamp(point_intensity + cluster_intensity, 0.0, 0.86);
	COLOR = vec4(glow_color.rgb, intensity);
}
