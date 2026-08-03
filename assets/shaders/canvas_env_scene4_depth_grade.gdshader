shader_type canvas_item;
render_mode unshaded;

// Shared Scene4 environment grade. Every art layer owns a separate
// ShaderMaterial instance so Eddy can tune depth roles directly in Inspector
// without changing the authored PNG or its transform.
uniform float brightness : hint_range(0.2, 1.2, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.4, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.3, 0.01) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float highlight_rolloff : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 haze_color : source_color = vec4(0.25, 0.40, 0.33, 1.0);
uniform float haze_strength : hint_range(0.0, 0.5, 0.01) = 0.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 color = source.rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));

	color = mix(vec3(luma), color, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;
	color = mix(color, color * tint_color.rgb, tint_strength);
	color /= vec3(1.0) + max(color, vec3(0.0)) * highlight_rolloff;

	float graded_luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 haze_target = haze_color.rgb * (0.55 + graded_luma * 0.45);
	color = mix(color, haze_target, haze_strength);

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source.a)
			* node_modulate;
}
