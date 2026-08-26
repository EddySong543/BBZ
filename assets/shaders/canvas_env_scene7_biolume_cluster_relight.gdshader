shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D cluster_mask : filter_nearest;
uniform vec4 glow_color : source_color = vec4(0.28, 0.92, 0.75, 1.0);
uniform float cluster_cycle_sec : hint_range(3.0, 12.0) = 9.5;
uniform float cluster_time_phase : hint_range(0.0, 1.0) = 0.0;
uniform float trough_brightness : hint_range(0.4, 1.0) = 0.72;
uniform float peak_brightness : hint_range(1.0, 1.5) = 1.16;
uniform float peak_tint_mix : hint_range(0.0, 0.5) = 0.18;
uniform float halo_base : hint_range(0.0, 0.2) = 0.018;
uniform float halo_peak : hint_range(0.0, 0.3) = 0.085;
uniform float diagnostic_time_sec = -1.0;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 mask_data = texture(cluster_mask, UV);
	float fx_time = diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
	float phase = fx_time / max(cluster_cycle_sec, 0.01) + cluster_time_phase;
	float breathe = 0.5 - 0.5 * cos(phase * 6.2831853);
	// Keep a long, readable middle instead of a brief sine-wave highlight.
	breathe = smoothstep(0.08, 0.92, breathe);

	float source_value = max(source.r, max(source.g, source.b));
	vec3 relit = source.rgb * mix(trough_brightness, peak_brightness, breathe);
	vec3 tinted_peak = glow_color.rgb * source_value * peak_brightness;
	relit = mix(relit, tinted_peak, peak_tint_mix * breathe);

	float core = mask_data.r * mask_data.a * source.a;
	float halo = mask_data.g * mask_data.a;
	float halo_alpha = halo * mix(halo_base, halo_peak, breathe);
	vec3 overlay_rgb = mix(glow_color.rgb, relit, step(0.001, core));
	float overlay_alpha = max(core, halo_alpha);
	COLOR = vec4(overlay_rgb, overlay_alpha);
}
