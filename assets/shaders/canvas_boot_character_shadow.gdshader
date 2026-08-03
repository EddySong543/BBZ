shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 shadow_color : source_color = vec4(
		0.0313725, 0.0392157, 0.0509804, 0.82);

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	COLOR = vec4(
			shadow_color.rgb,
			sampled.a * shadow_color.a) * vertex_color;
}
