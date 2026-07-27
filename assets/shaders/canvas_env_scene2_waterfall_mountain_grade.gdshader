shader_type canvas_item;
render_mode unshaded;

// Subtle shared grade for the three authored ridge copies behind Scene2's
// waterfall. This pass preserves source pixels and alpha exactly: it performs
// no neighborhood sampling, blur, palette replacement, or edge cleanup.
uniform float saturation : hint_range(0.75, 1.1, 0.01) = 0.92;
uniform float contrast : hint_range(0.85, 1.1, 0.01) = 0.97;
uniform float brightness : hint_range(0.9, 1.1, 0.005) = 0.995;
uniform vec4 atmosphere_color : source_color = vec4(0.52, 0.65, 0.67, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.2, 0.01) = 0.06;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luma), source.rgb, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	graded *= brightness;
	graded = mix(graded, atmosphere_color.rgb, atmosphere_strength);
	COLOR = vec4(
			clamp(graded, vec3(0.0), vec3(1.0)),
			source.a) * node_modulate;
}
