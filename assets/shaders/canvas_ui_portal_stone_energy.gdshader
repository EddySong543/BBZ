shader_type canvas_item;
render_mode unshaded;

uniform vec4 energy_color : source_color = vec4(1.0, 0.76, 0.24, 1.0);
uniform float energy_mix : hint_range(0.0, 1.0) = 0.0;
uniform float energy_threshold : hint_range(0.0, 1.0) = 0.58;
uniform float anim_time = 0.0;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float high_channel = max(source.r, max(source.g, source.b));
	float low_channel = min(source.r, min(source.g, source.b));
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float neutral_mask = 1.0 - smoothstep(0.12, 0.34, high_channel - low_channel);
	float bright_mask = smoothstep(energy_threshold, 0.94, luminance);
	float energy_mask = bright_mask * mix(0.38, 1.0, neutral_mask);
	float pulse = 0.90 + sin(anim_time * 2.15) * 0.07
			+ sin(anim_time * 5.73 + 1.4) * 0.03;
	vec3 tinted_light = energy_color.rgb * mix(0.72, 1.18, luminance) * pulse;
	vec3 result = mix(source.rgb, tinted_light, energy_mask * energy_mix);
	COLOR = vec4(result, source.a);
}
