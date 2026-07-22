shader_type canvas_item;
render_mode unshaded;

uniform vec4 zenith_wash : source_color = vec4(0.56, 0.72, 0.79, 1.0);
uniform vec4 horizon_wash : source_color = vec4(0.74, 0.82, 0.83, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 0.6;
uniform float wash_strength : hint_range(0.0, 1.0) = 0.32;
uniform float contrast : hint_range(0.5, 1.5) = 0.86;
uniform float lift : hint_range(-0.25, 0.25) = 0.07;
uniform float palette_steps : hint_range(8.0, 128.0) = 48.0;


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(vec3(luminance), tex.rgb, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5 + lift);
	vec3 wash = mix(
		zenith_wash.rgb,
		horizon_wash.rgb,
		smoothstep(0.08, 0.82, UV.y)
	);
	color = mix(color, wash, wash_strength);
	float lower_horizon = smoothstep(0.68, 0.9, UV.y);
	color = mix(color, horizon_wash.rgb, lower_horizon * 0.72);
	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * palette_steps + vec3(0.5)) / palette_steps;
	COLOR = vec4(color, tex.a);
}
