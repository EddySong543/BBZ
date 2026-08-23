shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_tint : source_color = vec4(0.025, 0.12, 0.16, 1.0);
uniform vec4 highlight_tint : source_color = vec4(0.48, 0.78, 0.76, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 0.5;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 day_palette = mix(shadow_tint.rgb, highlight_tint.rgb,
			smoothstep(0.08, 0.88, luma));
	vec3 color = mix(source.rgb, day_palette, grade_strength);
	float graded_luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(graded_luma), color, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;
	COLOR = vec4(max(color, vec3(0.0)), source.a * opacity);
}
