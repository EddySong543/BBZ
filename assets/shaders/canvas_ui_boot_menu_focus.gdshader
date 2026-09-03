shader_type canvas_item;
render_mode unshaded;

uniform vec2 visual_offset = vec2(0.0);
uniform float focus_strength : hint_range(0.0, 1.0) = 0.0;
uniform float press_strength : hint_range(0.0, 1.0) = 0.0;
uniform float focus_tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 focus_color : source_color = vec4(1.0, 0.86, 0.54, 1.0);

void vertex() {
	VERTEX += visual_offset;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float tint_amount = focus_strength * focus_tint_strength * source.a;
	source.rgb = mix(source.rgb, focus_color.rgb, tint_amount);
	source.rgb *= mix(1.0, 0.88, press_strength);
	COLOR = source;
}
