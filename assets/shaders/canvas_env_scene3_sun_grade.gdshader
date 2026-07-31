shader_type canvas_item;
render_mode unshaded, blend_mix;

// The middle value is sampled from the composited bottom band of Sky1 + Sky2.
// Reconstructing the palette prevents the source sun's gray-yellow cast.
uniform vec4 shadow_color : source_color = vec4(0.43, 0.24, 0.17, 1.0);
uniform vec4 mid_color : source_color = vec4(0.89, 0.63, 0.47, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.82, 0.56, 1.0);
uniform float mid_point : hint_range(0.25, 0.75, 0.01) = 0.5;
uniform float contrast : hint_range(0.5, 1.4, 0.01) = 1.05;
uniform float brightness : hint_range(0.5, 1.4, 0.01) = 1.08;
uniform vec4 cloud_shadow_color : source_color = vec4(0.48, 0.43, 0.39, 1.0);
uniform float cloud_shadow_strength : hint_range(0.0, 0.6, 0.01) = 0.08;
uniform float alpha_scale : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform float palette_steps : hint_range(8.0, 96.0, 1.0) = 48.0;
uniform vec4 outline_soften_color : source_color = vec4(0.94, 0.66, 0.49, 1.0);
uniform float outline_soften_strength : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float outline_alpha_reduction : hint_range(0.0, 0.8, 0.01) = 0.58;
uniform float outline_sample_px : hint_range(1.0, 8.0, 1.0) = 5.0;
uniform float fade_start : hint_range(0.2, 0.7, 0.01) = 0.40;
uniform float fade_end : hint_range(0.3, 0.8, 0.01) = 0.56;
uniform float pulse_cycle_sec : hint_range(3.0, 16.0, 0.1) = 7.8;
uniform float pulse_amount : hint_range(0.0, 0.2, 0.005) = 0.065;
uniform float surface_shimmer_amount : hint_range(0.0, 0.12, 0.005) = 0.035;


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		discard;
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float tone = clamp((luma - 0.5) * contrast + 0.5, 0.0, 1.0);
	float low_mix = smoothstep(0.0, mid_point, tone);
	float high_mix = smoothstep(mid_point, 1.0, tone);
	vec3 color = mix(shadow_color.rgb, mid_color.rgb, low_mix);
	color = mix(color, highlight_color.rgb, high_mix);
	float pulse_phase = TIME * TAU / max(pulse_cycle_sec, 0.001);
	float pulse = 1.0 + sin(pulse_phase) * pulse_amount;
	float radial_distance = length(UV - vec2(0.5));
	float radial_edge_light = smoothstep(0.24, 0.49, radial_distance);
	float angle = atan(UV.y - 0.5, UV.x - 0.5);
	float surface_shimmer = (
			0.5 + 0.5 * sin(angle * 7.0 + pulse_phase * 0.72))
			* radial_edge_light
			* surface_shimmer_amount;
	color *= brightness * pulse;
	color = mix(
			color,
			highlight_color.rgb,
			surface_shimmer);

	vec2 edge_offset = TEXTURE_PIXEL_SIZE * outline_sample_px;
	float neighbor_alpha = min(
			min(
					texture(TEXTURE, UV - vec2(edge_offset.x, 0.0)).a,
					texture(TEXTURE, UV + vec2(edge_offset.x, 0.0)).a),
			min(
					texture(TEXTURE, UV - vec2(0.0, edge_offset.y)).a,
					texture(TEXTURE, UV + vec2(0.0, edge_offset.y)).a));
	float exposed_edge = tex.a * (1.0 - neighbor_alpha);
	float radial_edge = smoothstep(
			0.37, 0.49, length(UV - vec2(0.5)));
	float dark_ink = 1.0 - smoothstep(0.16, 0.42, luma);
	float asset_outline = max(
			exposed_edge,
			radial_edge * dark_ink * tex.a);
	float preserve_upper_arc = (
			1.0 - smoothstep(0.13, 0.34, UV.y)) * 0.28;
	float edge_soften = asset_outline * (1.0 - preserve_upper_arc);
	color = mix(
			color,
			outline_soften_color.rgb * mix(0.72, 1.0, tone),
			edge_soften * outline_soften_strength);
	float cloud_depth = smoothstep(0.48, 1.0, UV.y);
	color = mix(
			color,
			color * cloud_shadow_color.rgb,
			cloud_depth * cloud_shadow_strength);
	color = floor(
			clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)
	) / palette_steps;
	float lower_fade = 1.0 - smoothstep(
			fade_start,
			max(fade_end, fade_start + 0.001),
			UV.y);
	float softened_alpha = tex.a
			* (1.0 - edge_soften * outline_alpha_reduction);
	COLOR = vec4(color, softened_alpha * alpha_scale * lower_fade);
}
