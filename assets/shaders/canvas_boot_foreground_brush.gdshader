shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 tint_color : source_color = vec4(
		0.141176, 0.211765, 0.309804, 1.0);
uniform float opacity : hint_range(0.0, 0.5, 0.01) = 0.18;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.84;
uniform float fringe_cleanup : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform sampler2D intro_path_texture : repeat_disable, filter_nearest;
uniform float intro_stroke_progress : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float intro_stroke_feather : hint_range(0.02, 0.24, 0.001) = 0.15;

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);

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
	float path_progress = texture(intro_path_texture, UV).r;
	float intro_reveal = (
			smoothstep(
					path_progress - intro_stroke_feather,
					path_progress,
					intro_stroke_progress));
	if (intro_stroke_progress <= 0.001) {
		intro_reveal = 0.0;
	} else if (intro_stroke_progress >= 0.999) {
		intro_reveal = 1.0;
	}
	COLOR = vec4(
			colored,
			cleaned_alpha
			* clamp(opacity, 0.0, 0.5)
			* intro_reveal
		) * vertex_color;
}
