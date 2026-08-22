shader_type canvas_item;
render_mode unshaded;

// Scene6 forged platform grade. Geometry and alpha remain locked to source
// texels; only the warm fissure pixels carry a restrained travelling heat.
uniform float brightness : hint_range(0.3, 1.3, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.4, 0.01) = 0.66;
uniform float contrast : hint_range(0.5, 1.4, 0.01) = 1.06;
uniform vec4 tint_color : source_color = vec4(0.78, 0.50, 0.46, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.04;
uniform float highlight_rolloff : hint_range(0.0, 1.0, 0.01) = 0.14;
uniform vec4 palette_shadow : source_color = vec4(0.032, 0.020, 0.032, 1.0);
uniform vec4 palette_mid : source_color = vec4(0.205, 0.112, 0.120, 1.0);
uniform vec4 palette_light : source_color = vec4(0.46, 0.235, 0.205, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 0.48;
uniform float palette_source_dark : hint_range(0.0, 0.5, 0.01) = 0.025;
uniform float palette_source_light : hint_range(0.1, 1.0, 0.01) = 0.54;

uniform vec4 lava_hot_color : source_color = vec4(1.0, 0.31, 0.055, 1.0);
uniform vec4 lava_core_color : source_color = vec4(1.0, 0.61, 0.17, 1.0);
uniform float fissure_source_restore : hint_range(0.0, 1.0, 0.01) = 0.74;
uniform float lava_base_heat : hint_range(0.0, 0.6, 0.01) = 0.18;
uniform float lava_pulse_strength : hint_range(0.0, 0.8, 0.01) = 0.36;
uniform float lava_moving_gain : hint_range(0.0, 0.3, 0.01) = 0.09;
uniform float lava_cycle_sec : hint_range(5.0, 18.0, 0.1) = 10.8;
uniform float lava_flow_cycles : hint_range(1.0, 10.0, 0.1) = 4.4;
uniform float lava_phase : hint_range(0.0, 6.3, 0.01) = 1.1;
uniform vec2 lava_flow_axis = vec2(0.04, 1.0);
uniform float lava_red_threshold : hint_range(0.2, 0.9, 0.01) = 0.54;
uniform float lava_orange_threshold : hint_range(0.0, 0.4, 0.005) = 0.07;
uniform float lava_luma_threshold : hint_range(0.05, 0.8, 0.01) = 0.25;
uniform float motion_feather : hint_range(0.03, 0.4, 0.01) = 0.17;

uniform vec4 lava_bounce_color : source_color = vec4(0.72, 0.16, 0.035, 1.0);
uniform float lava_bounce_amount : hint_range(0.0, 0.25, 0.005) = 0.018;
uniform float lava_bounce_start : hint_range(0.0, 1.0, 0.01) = 0.62;
uniform float broken_reflection_amount : hint_range(0.0, 0.15, 0.005) = 0.02;
uniform float broken_reflection_coverage : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform float broken_reflection_start : hint_range(0.0, 1.0, 0.01) = 0.50;
uniform float broken_reflection_end : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform float broken_reflection_segments : hint_range(16.0, 160.0, 1.0) = 96.0;
uniform float inner_bounce_amount : hint_range(0.0, 0.15, 0.005) = 0.0;
uniform float inner_bounce_direction : hint_range(-1.0, 1.0, 1.0) = 0.0;
uniform float inner_bounce_start : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float inner_bounce_vertical_start : hint_range(0.0, 1.0, 0.01) = 0.28;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash11(float value) {
	return fract(sin(value * 127.1 + 19.73) * 43758.5453);
}


float platform_lava_mask(vec4 source_texel) {
	float luma = dot(source_texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float red_gate = smoothstep(
			lava_red_threshold,
			lava_red_threshold + 0.18,
			source_texel.r);
	float orange_gate = smoothstep(
			lava_orange_threshold,
			lava_orange_threshold + 0.12,
			source_texel.g - source_texel.b);
	float light_gate = smoothstep(
			lava_luma_threshold,
			lava_luma_threshold + 0.20,
			luma);
	return red_gate * orange_gate * light_gate * source_texel.a;
}


float thermal_flow(vec2 source_pixel, vec2 source_size) {
	vec2 axis = normalize(lava_flow_axis);
	float along = dot(source_pixel / max(source_size, vec2(1.0)), axis);
	float column_group = floor(source_pixel.x / 12.0);
	float column_phase = hash11(column_group + 7.0) * 0.18;
	float travel = TIME / max(lava_cycle_sec, 0.001);
	float phase = fract(
			along * lava_flow_cycles
			- travel
			+ lava_phase / 6.2831853
			+ column_phase);
	float distance_a = min(abs(phase - 0.22), 1.0 - abs(phase - 0.22));
	float distance_b = min(abs(phase - 0.70), 1.0 - abs(phase - 0.70));
	float band_a = 1.0 - smoothstep(0.045, 0.045 + motion_feather, distance_a);
	float band_b = 1.0 - smoothstep(0.035, 0.035 + motion_feather * 0.82, distance_b);
	return max(band_a, band_b * 0.58);
}


void fragment() {
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	vec2 source_pixel = floor(UV * source_size);
	vec2 source_uv = (source_pixel + vec2(0.5)) / max(source_size, vec2(1.0));
	vec4 source_texel = texture(TEXTURE, source_uv);
	vec3 color = source_texel.rgb;
	float source_luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(source_luma), color, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;
	color = mix(color, color * tint_color.rgb, tint_strength);
	color /= vec3(1.0) + max(color, vec3(0.0)) * highlight_rolloff;

	float palette_value = clamp(
			(source_luma - palette_source_dark)
			/ max(palette_source_light - palette_source_dark, 0.001),
			0.0,
			1.0);
	vec3 mapped_palette = mix(
			palette_shadow.rgb,
			palette_mid.rgb,
			smoothstep(0.0, 0.62, palette_value));
	mapped_palette = mix(
			mapped_palette,
			palette_light.rgb,
			smoothstep(0.56, 1.0, palette_value));
	color = mix(color, mapped_palette, palette_strength);

	float graded_luma = dot(color, vec3(0.299, 0.587, 0.114));
	float bounce = floor(smoothstep(lava_bounce_start, 1.0, UV.y) * 4.0 + 0.5) / 4.0;
	color += lava_bounce_color.rgb
			* lava_bounce_amount
			* bounce
			* (1.0 - graded_luma * 0.76);

	float reflection_band = smoothstep(
			broken_reflection_start,
			broken_reflection_start + 0.07,
			UV.y);
	reflection_band *= 1.0 - smoothstep(
			broken_reflection_end - 0.07,
			broken_reflection_end,
			UV.y);
	float reflection_segment = floor(UV.x * broken_reflection_segments);
	float reflection_gate = step(
			1.0 - broken_reflection_coverage,
			hash11(reflection_segment));
	float broken_reflection = reflection_band * reflection_gate;
	color += lava_bounce_color.rgb
			* broken_reflection_amount
			* broken_reflection
			* (1.0 - graded_luma * 0.82);

	float inner_coord = mix(
			1.0 - UV.x,
			UV.x,
			step(0.0, inner_bounce_direction));
	float inner_facing_bounce = smoothstep(
			inner_bounce_start, 1.0, inner_coord);
	inner_facing_bounce *= smoothstep(
			inner_bounce_vertical_start, 1.0, UV.y);
	color += lava_bounce_color.rgb
			* inner_bounce_amount
			* inner_facing_bounce
			* (1.0 - graded_luma * 0.86);

	// Preserve the authored crack topology, then move only a small amount of
	// heat through it. No UV displacement or scene-wide breathing is used.
	float lava_mask = platform_lava_mask(source_texel);
	float flow = thermal_flow(source_pixel, source_size);
	vec3 restored_fissure = mix(source_texel.rgb, lava_hot_color.rgb, 0.12);
	color = mix(color, restored_fissure, lava_mask * fissure_source_restore);
	float hot_mix = lava_mask * (
			lava_base_heat
			+ lava_pulse_strength * (0.10 + flow * 0.90));
	float core_mix = lava_mask * lava_pulse_strength * flow
			* smoothstep(0.72, 0.94, source_texel.r);
	color = mix(color, lava_hot_color.rgb, hot_mix * 0.42);
	color = mix(color, lava_core_color.rgb, core_mix * 0.24);
	color += lava_hot_color.rgb * lava_mask * flow * lava_moving_gain;

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source_texel.a)
			* node_modulate;
}
