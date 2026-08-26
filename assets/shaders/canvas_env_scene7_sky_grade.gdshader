shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene7 Scheme B sky. Rebuild only the source sky palette while preserving
// its authored value variation and pixel structure.
uniform vec4 zenith_color : source_color = vec4(0.58, 0.82, 0.69, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.7, 0.9, 0.72, 1.0);
uniform vec4 horizon_haze_color : source_color = vec4(0.92, 0.95, 0.78, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0) = 0.94;
uniform float source_value_detail : hint_range(0.0, 0.5) = 0.12;
uniform float horizon_haze_strength : hint_range(0.0, 0.3) = 0.05;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float source_luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float vertical = smoothstep(0.04, 0.88, UV.y);
	vec3 mint_ramp = mix(zenith_color.rgb, horizon_color.rgb, vertical);
	float ramp_luma = dot(mint_ramp, vec3(0.2126, 0.7152, 0.0722));
	vec3 value_matched = mint_ramp
			* (source_luma / max(ramp_luma, 0.001));
	vec3 target = mix(mint_ramp, value_matched, source_value_detail);
	vec3 color = mix(source.rgb, target, palette_strength);
	float haze = smoothstep(0.58, 1.0, UV.y) * horizon_haze_strength;
	color = mix(color, horizon_haze_color.rgb, haze);
	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * 63.0 + 0.5) / 63.0;
	COLOR = vec4(color, source.a);
}
