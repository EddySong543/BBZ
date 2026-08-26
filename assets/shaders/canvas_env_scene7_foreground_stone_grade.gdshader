shader_type canvas_item;
render_mode unshaded, blend_mix;

// Match the body grading of the two authored foreground banks, but omit their
// plant emission and sway so the duplicated stone remains a dark solid mass.
uniform vec4 ambient_tint : source_color = vec4(0.52, 0.58, 0.72, 1.0);
uniform vec4 cool_body_tint : source_color = vec4(0.08, 0.33, 0.42, 1.0);
uniform vec4 shadow_palette : source_color = vec4(0.02, 0.06, 0.14, 1.0);
uniform vec4 sunlit_palette : source_color = vec4(0.19, 0.27, 0.39, 1.0);
uniform float cool_body_tint_mix : hint_range(0.0, 0.3) = 0.15;
uniform float palette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float base_brightness : hint_range(0.5, 1.2) = 0.74;
uniform float highlight_ceiling : hint_range(0.15, 0.8) = 0.36;


float cool_source_presence(vec3 color) {
	float cool_value = max(color.g, color.b);
	float warm_value = max(color.r, min(color.g, color.b) * 0.34);
	return smoothstep(0.08, 0.34, cool_value - warm_value);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float source_value = max(source.r, max(source.g, source.b));
	float tint_peak = max(cool_body_tint.r,
			max(cool_body_tint.g, cool_body_tint.b));
	vec3 teal_target = cool_body_tint.rgb
			* (source_value / max(tint_peak, 0.001));
	vec3 authored_body = mix(
			source.rgb,
			teal_target,
			cool_source_presence(source.rgb) * cool_body_tint_mix);
	float source_luma = dot(
			authored_body, vec3(0.2126, 0.7152, 0.0722));
	float palette_lerp = smoothstep(0.12, 0.72, source_luma);
	vec3 oasis_palette = mix(
			shadow_palette.rgb, sunlit_palette.rgb, palette_lerp);
	vec3 shaded = mix(
			authored_body * ambient_tint.rgb,
			oasis_palette,
			palette_strength) * base_brightness;
	float shaded_value = max(shaded.r, max(shaded.g, shaded.b));
	shaded *= min(1.0, highlight_ceiling / max(shaded_value, 0.001));
	COLOR = vec4(max(shaded, vec3(0.0)), source.a);
}
