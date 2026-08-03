shader_type canvas_item;
render_mode unshaded;

// Scene4-only grade for Eddy's authored banded sky. The source luminance and
// horizontal layers stay intact; only the purple-gray palette is remapped to a
// restrained sage / mist-green range.
uniform vec4 shadow_color : source_color = vec4(0.12, 0.16, 0.20, 1.0);
uniform vec4 mid_color : source_color = vec4(0.23, 0.32, 0.33, 1.0);
uniform vec4 light_color : source_color = vec4(0.34, 0.42, 0.40, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0, 0.01) = 0.86;
uniform float source_dark : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float source_light : hint_range(0.1, 0.8, 0.01) = 0.26;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float value = clamp(
			(luma - source_dark) / max(source_light - source_dark, 0.001),
			0.0,
			1.0);
	vec3 palette = mix(
			shadow_color.rgb,
			mid_color.rgb,
			smoothstep(0.0, 0.62, value));
	palette = mix(
			palette,
			light_color.rgb,
			smoothstep(0.58, 1.0, value));
	vec3 color = mix(source.rgb, palette, grade_strength);
	COLOR = vec4(color, source.a) * node_modulate;
}
