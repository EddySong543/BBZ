shader_type canvas_item;
render_mode unshaded;

// The mask alpha is authored at the same pixel resolution as boot_char2.
// Only the face and hands have non-zero alpha, so clothing can never be
// recolored by the skin grade.
uniform sampler2D skin_mask_texture : filter_nearest, repeat_disable;
uniform float skin_lift : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform float skin_warmth : hint_range(-0.25, 0.25, 0.01) = 0.08;


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float skin_mask = texture(skin_mask_texture, UV).a;

	vec3 lifted = pow(max(tex.rgb, vec3(0.0)), vec3(0.70));
	lifted += vec3(0.055, 0.020, -0.012) * skin_warmth;

	vec3 graded = mix(
		tex.rgb,
		clamp(lifted, vec3(0.0), vec3(1.0)),
		skin_mask * skin_lift
	);

	COLOR = vec4(graded, tex.a);
}
