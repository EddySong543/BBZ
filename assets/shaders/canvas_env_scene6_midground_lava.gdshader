shader_type canvas_item;
render_mode unshaded;

// Scene6 midground grade plus source-color-selective lava animation. The
// source UV and alpha never move: only existing orange-red pixels carry heat.
uniform float brightness : hint_range(0.3, 1.3, 0.01) = 0.92;
uniform float saturation : hint_range(0.0, 1.4, 0.01) = 0.88;
uniform float contrast : hint_range(0.5, 1.4, 0.01) = 1.04;
uniform vec4 palette_shadow : source_color = vec4(0.055, 0.018, 0.035, 1.0);
uniform vec4 palette_mid : source_color = vec4(0.27, 0.07, 0.085, 1.0);
uniform vec4 palette_light : source_color = vec4(0.69, 0.20, 0.11, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float palette_source_dark : hint_range(0.0, 0.5, 0.01) = 0.025;
uniform float palette_source_light : hint_range(0.1, 1.0, 0.01) = 0.58;

uniform vec4 lava_hot_color : source_color = vec4(1.0, 0.30, 0.055, 1.0);
uniform vec4 lava_core_color : source_color = vec4(1.0, 0.60, 0.16, 1.0);
uniform float lava_pulse_strength : hint_range(0.0, 0.8, 0.01) = 0.34;
uniform float lava_base_heat : hint_range(0.0, 0.6, 0.01) = 0.18;
uniform float lava_band_width : hint_range(0.6, 1.8, 0.01) = 1.0;
uniform float lava_moving_gain : hint_range(0.0, 0.4, 0.01) = 0.18;
uniform float lava_cycle_sec : hint_range(4.0, 16.0, 0.1) = 8.8;
uniform float lava_phase : hint_range(0.0, 6.3, 0.01) = 0.0;
uniform vec2 lava_flow_axis = vec2(0.08, 1.0);
uniform float lava_flow_cycles : hint_range(1.0, 10.0, 0.1) = 4.2;
uniform float lava_red_threshold : hint_range(0.2, 0.9, 0.01) = 0.55;
uniform float lava_orange_threshold : hint_range(0.0, 0.3, 0.005) = 0.025;
uniform float lava_luma_threshold : hint_range(0.05, 0.7, 0.01) = 0.22;
uniform float motion_feather : hint_range(0.02, 0.4, 0.01) = 0.18;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float lava_color_mask(vec4 source_texel) {
	float luma = dot(source_texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float red_gate = smoothstep(
			lava_red_threshold,
			lava_red_threshold + 0.18,
			source_texel.r);
	float orange_gate = smoothstep(
			lava_orange_threshold,
			lava_orange_threshold + 0.08,
			source_texel.g - source_texel.b);
	float light_gate = smoothstep(
			lava_luma_threshold,
			lava_luma_threshold + 0.18,
			luma);
	return red_gate * orange_gate * light_gate * source_texel.a;
}


float thermal_flow(vec2 source_pixel, vec2 source_size) {
	vec2 axis = normalize(lava_flow_axis);
	float along = dot(source_pixel / max(source_size, vec2(1.0)), axis);
	float column_group = floor(source_pixel.x / 9.0);
	float column_phase = fract(sin(column_group * 37.17) * 43758.5453);
	float travel = TIME / max(lava_cycle_sec, 0.001);
	float phase = fract(
			along * lava_flow_cycles
			- travel
			+ lava_phase / 6.2831853
			+ column_phase * 0.22);
	float band_a = 1.0 - smoothstep(
			0.05,
			0.05 + motion_feather * lava_band_width,
			abs(phase - 0.20));
	float band_b = 1.0 - smoothstep(
			0.04,
			0.04 + motion_feather * 0.82 * lava_band_width,
			abs(phase - 0.72));
	return max(band_a, band_b * 0.62);
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

	float lava_mask = lava_color_mask(source_texel);
	float flow = thermal_flow(source_pixel, source_size);
	float hot_mix = lava_mask * (
			lava_base_heat
			+ lava_pulse_strength * (0.10 + flow * 0.90));
	float core_mix = lava_mask * lava_pulse_strength * flow
			* smoothstep(0.42, 0.72, source_texel.r);
	color = mix(color, lava_hot_color.rgb, hot_mix);
	color = mix(color, lava_core_color.rgb, core_mix * 0.34);
	color += lava_hot_color.rgb * lava_mask * flow * lava_moving_gain;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source_texel.a)
			* node_modulate;
}
