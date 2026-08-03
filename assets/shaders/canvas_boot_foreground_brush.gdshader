shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 tint_color : source_color = vec4(
		0.141176, 0.211765, 0.309804, 1.0);
uniform float opacity : hint_range(0.0, 0.5, 0.01) = 0.18;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.84;
uniform float fringe_cleanup : hint_range(0.0, 0.5, 0.01) = 0.14;

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float lower_left = (
			(1.0 - smoothstep(0.30, 0.56, UV.x))
			* smoothstep(0.62, 0.91, UV.y));
	float upper_right = (
			smoothstep(0.72, 0.94, UV.x)
			* (1.0 - smoothstep(0.12, 0.38, UV.y)));
	float broad_edge_mask = max(lower_left, upper_right);

	vec3 colored = mix(
			source.rgb,
			tint_color.rgb,
			clamp(tint_strength, 0.0, 1.0));
	float cleaned_alpha = (
			source.a
			* smoothstep(
					fringe_cleanup,
					fringe_cleanup + 0.22,
					source.a));
	COLOR = vec4(
			colored,
			cleaned_alpha
			* broad_edge_mask
			* clamp(opacity, 0.0, 0.5)
		) * vertex_color;
}
