shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float wave_speed : hint_range(0.0, 0.1, 0.001) = 0.022;
uniform float wave_phase : hint_range(0.0, 1.0, 0.001) = 0.055;
uniform float wave_width : hint_range(0.05, 0.35, 0.01) = 0.17;
uniform float secondary_offset : hint_range(0.1, 0.8, 0.01) = 0.43;
uniform float secondary_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float light_strength : hint_range(0.0, 0.8, 0.01) = 0.34;
uniform vec4 light_color : source_color = vec4(1.0, 0.86, 0.42, 1.0);
uniform float gold_left : hint_range(0.0, 0.5, 0.01) = 0.20;
uniform float gold_right : hint_range(0.5, 1.0, 0.01) = 0.89;
uniform float gold_ratio_threshold : hint_range(0.3, 0.8, 0.01) = 0.51;
uniform float gold_luminance_threshold : hint_range(0.2, 0.8, 0.01) = 0.42;
uniform float gold_rest_dim : hint_range(0.0, 0.25, 0.01) = 0.08;
uniform float bottom_edge_trim : hint_range(0.0, 1.0, 0.01) = 1.0;


float gold_region_mask(vec2 uv) {
	float side_exclusion = step(gold_left, uv.x) * step(uv.x, gold_right);
	return side_exclusion;
}


float gold_color_mask(vec4 source_texel) {
	float green_red_ratio = source_texel.g / max(source_texel.r, 0.001);
	float luminance = dot(
			source_texel.rgb,
			vec3(0.2126, 0.7152, 0.0722));
	float ratio_mask = smoothstep(
			gold_ratio_threshold,
			gold_ratio_threshold + 0.06,
			green_red_ratio);
	float light_mask = smoothstep(
			gold_luminance_threshold,
			gold_luminance_threshold + 0.1,
			luminance);
	return ratio_mask * light_mask * source_texel.a;
}


float synchronized_wave(float x) {
	float center = fract(TIME * wave_speed + wave_phase);
	float primary_distance = abs(fract(x - center + 0.5) - 0.5);
	float primary = 1.0 - smoothstep(
			wave_width * 0.58,
			wave_width,
			primary_distance);
	float secondary_center = fract(center - secondary_offset);
	float secondary_distance = abs(
			fract(x - secondary_center + 0.5) - 0.5);
	float secondary = 1.0 - smoothstep(
			wave_width * 0.38,
			wave_width * 0.72,
			secondary_distance);
	return max(primary, secondary * secondary_strength);
}


float ridge_bottom_edge_mask(
		vec4 source_texel,
		float below_1,
		float below_2) {
	float opaque_1 = step(0.05, below_1);
	float opaque_2 = step(0.05, below_2);
	float last_row = 1.0 - opaque_1;
	float penultimate_row = opaque_1 * (1.0 - opaque_2) * 0.58;
	return source_texel.a * max(last_row, penultimate_row);
}


void fragment() {
	vec4 source_texel = texture(TEXTURE, UV);
	vec4 texel = source_texel * COLOR;
	vec2 source_pixel = 1.0 / vec2(textureSize(TEXTURE, 0));
	float bottom_edge = ridge_bottom_edge_mask(
			source_texel,
			texture(TEXTURE, UV + vec2(0.0, source_pixel.y)).a,
			texture(TEXTURE, UV + vec2(0.0, source_pixel.y * 2.0)).a);
	texel.a *= 1.0 - bottom_edge * bottom_edge_trim;
	float gold_only = gold_region_mask(UV) * gold_color_mask(source_texel);
	float wave = synchronized_wave(UV.x);
	float sweep = wave * gold_only;
	texel.rgb *= 1.0 - gold_only * (1.0 - wave) * gold_rest_dim;
	texel.rgb = mix(
			texel.rgb,
			light_color.rgb,
			sweep * light_strength);
	texel.rgb *= 1.0 + sweep * light_strength * 0.2;
	COLOR = texel;
}
