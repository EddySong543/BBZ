shader_type canvas_item;
render_mode unshaded;

// Scene6 far-depth grade plus source-preserving crack heat. The source image
// is broadly red, so the mask uses relative yellow content and local lightness
// instead of a red threshold. UV, alpha, and mountain silhouettes stay fixed.
uniform float brightness : hint_range(0.3, 1.3, 0.01) = 0.84;
uniform float saturation : hint_range(0.0, 1.4, 0.01) = 0.72;
uniform float contrast : hint_range(0.5, 1.4, 0.01) = 0.92;
uniform vec4 tint_color : source_color = vec4(0.86, 0.48, 0.42, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.07;
uniform float highlight_rolloff : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform vec4 palette_shadow : source_color = vec4(0.065, 0.022, 0.040, 1.0);
uniform vec4 palette_mid : source_color = vec4(0.31, 0.075, 0.078, 1.0);
uniform vec4 palette_light : source_color = vec4(0.64, 0.17, 0.09, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float palette_source_dark : hint_range(0.0, 0.5, 0.01) = 0.025;
uniform float palette_source_light : hint_range(0.1, 1.0, 0.01) = 0.62;
uniform vec4 crack_hot_color : source_color = vec4(1.0, 0.34, 0.07, 1.0);
uniform vec4 crack_core_color : source_color = vec4(1.0, 0.62, 0.16, 1.0);
uniform float crack_pulse_strength : hint_range(0.0, 1.2, 0.01) = 0.92;
uniform float far_moving_gain : hint_range(0.0, 0.5, 0.01) = 0.26;
uniform float afterglow_strength : hint_range(0.0, 0.5, 0.01) = 0.20;
uniform float crack_cycle_sec : hint_range(7.0, 20.0, 0.1) = 13.5;
uniform float crack_phase : hint_range(0.0, 6.3, 0.01) = 1.2;
uniform float yellow_ratio_threshold : hint_range(0.1, 0.5, 0.01) = 0.18;
uniform float crack_luma_threshold : hint_range(0.05, 0.7, 0.01) = 0.17;
uniform float crack_coverage_limit : hint_range(0.01, 0.12, 0.01) = 0.08;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float far_crack_mask(vec4 source_texel) {
	float luma = dot(source_texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float yellow_ratio = source_texel.g / max(source_texel.r, 0.001);
	float yellow_gate = smoothstep(
			yellow_ratio_threshold,
			yellow_ratio_threshold + 0.12,
			yellow_ratio);
	float light_gate = smoothstep(
			crack_luma_threshold,
			crack_luma_threshold + 0.10,
			luma);
	float red_heat_gate = smoothstep(0.10, 0.22,
			source_texel.r - source_texel.g);
	float blue_reject = 1.0 - smoothstep(0.16, 0.34, source_texel.b);
	return yellow_gate * light_gate * red_heat_gate * blue_reject * source_texel.a
			* clamp(crack_coverage_limit / 0.08, 0.0, 1.35);
}


vec2 far_lava_flow(vec2 source_pixel, vec2 source_size) {
	float along = source_pixel.y / max(source_size.y, 1.0);
	float column_phase = fract(sin(floor(source_pixel.x / 14.0) * 31.73) * 43758.5453);
	float phase = fract(
			along * 3.75
			- TIME / max(crack_cycle_sec, 0.001)
			+ crack_phase / 6.2831853
			+ column_phase * 0.24);
	float moving_heat_gain = 1.0 - smoothstep(0.055, 0.19, abs(phase - 0.25));
	float second_core = 1.0 - smoothstep(0.045, 0.15, abs(phase - 0.70));
	float flow_afterglow = 1.0 - smoothstep(0.10, 0.29, abs(phase - 0.40));
	return vec2(max(moving_heat_gain, second_core * 0.72), flow_afterglow);
}


void fragment() {
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	vec2 source_pixel = floor(UV * source_size);
	vec2 source_uv = (source_pixel + vec2(0.5)) / max(source_size, vec2(1.0));
	vec4 source = texture(TEXTURE, source_uv);
	vec3 color = source.rgb;
	float source_luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(source_luma), color, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;
	color = mix(color, color * tint_color.rgb, tint_strength);
	color /= vec3(1.0) + max(color, vec3(0.0)) * highlight_rolloff;

	float graded_luma = dot(color, vec3(0.299, 0.587, 0.114));
	float palette_value = clamp(
			(graded_luma - palette_source_dark)
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

	float crack_mask = far_crack_mask(source);
	vec2 flow_state = far_lava_flow(source_pixel, source_size);
	float moving_heat_gain = flow_state.x;
	float flow_afterglow = flow_state.y;
	float heat = crack_mask * crack_pulse_strength
			* (0.12 + moving_heat_gain * 0.88);
	color = mix(color, crack_hot_color.rgb, heat);
	color = mix(color, crack_core_color.rgb,
			crack_mask * moving_heat_gain * far_moving_gain);
	color += crack_hot_color.rgb * crack_mask * flow_afterglow
			* afterglow_strength;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source.a) * node_modulate;
}
