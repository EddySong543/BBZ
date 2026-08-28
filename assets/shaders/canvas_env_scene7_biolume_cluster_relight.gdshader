shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D cluster_mask : filter_nearest, repeat_disable;
uniform vec4 glow_color : source_color = vec4(0.28, 0.92, 0.75, 1.0);
uniform float cluster_cycle_sec : hint_range(3.0, 12.0) = 9.5;
uniform float cluster_time_phase : hint_range(0.0, 1.0) = 0.0;
uniform float animation_seed : hint_range(0.0, 1.0) = 0.5;
uniform float trough_brightness : hint_range(0.4, 1.0) = 0.72;
uniform float peak_brightness : hint_range(1.0, 1.5) = 1.16;
uniform float peak_tint_mix : hint_range(0.0, 0.5) = 0.18;
uniform float halo_base : hint_range(0.0, 0.2) = 0.018;
uniform float halo_peak : hint_range(0.0, 0.3) = 0.085;
uniform float diagnostic_time_sec = -1.0;


float hash11(float value) {
	return fract(sin(value) * 43758.5453123);
}


float seeded_cluster_breathe(float fx_time) {
	float cycle_seed = hash11(animation_seed * 83.17 + 0.37);
	float shape_seed = hash11(animation_seed * 47.11 + 0.71);
	float cycle_scale = mix(0.86, 1.14, cycle_seed);
	float phase = fx_time / max(cluster_cycle_sec * cycle_scale, 0.01)
			+ cluster_time_phase + animation_seed * 0.19;
	float main_breathe = 0.5 - 0.5 * cos(phase * 6.2831853);
	float secondary = 0.5 + 0.5 * sin(
			phase * 3.3300882 + animation_seed * 11.173);
	float irregular = mix(main_breathe, secondary, 0.10 + shape_seed * 0.06);
	return smoothstep(
			mix(0.05, 0.12, shape_seed),
			mix(0.86, 0.95, cycle_seed),
			irregular);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 mask_data = texture(cluster_mask, UV);
	float fx_time = diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
	float breathe = seeded_cluster_breathe(fx_time);

	float source_value = max(source.r, max(source.g, source.b));
	vec3 relit = source.rgb * mix(trough_brightness, peak_brightness, breathe);
	vec3 tinted_peak = glow_color.rgb * source_value * peak_brightness;
	relit = mix(relit, tinted_peak, peak_tint_mix * breathe);

	float core = mask_data.r * mask_data.a * source.a;
	float halo = mask_data.g * mask_data.a;
	vec2 cluster_texel = 1.0 / vec2(textureSize(cluster_mask, 0));
	float expanded_cluster_halo = 0.0;
	expanded_cluster_halo = max(expanded_cluster_halo,
			texture(cluster_mask, UV + vec2(cluster_texel.x, 0.0)).a);
	expanded_cluster_halo = max(expanded_cluster_halo,
			texture(cluster_mask, UV - vec2(cluster_texel.x, 0.0)).a);
	expanded_cluster_halo = max(expanded_cluster_halo,
			texture(cluster_mask, UV + vec2(0.0, cluster_texel.y)).a);
	expanded_cluster_halo = max(expanded_cluster_halo,
			texture(cluster_mask, UV - vec2(0.0, cluster_texel.y)).a);
	expanded_cluster_halo *= 1.0 - mask_data.a;
	float halo_alpha = halo * mix(halo_base, halo_peak, breathe);
	halo_alpha += expanded_cluster_halo * mix(0.008, 0.06, breathe);
	vec3 overlay_rgb = mix(glow_color.rgb, relit, step(0.001, core));
	float overlay_alpha = max(core, halo_alpha);
	COLOR = vec4(overlay_rgb, overlay_alpha);
}
