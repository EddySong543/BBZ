shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 tint_color : source_color = vec4(0.58, 0.68, 0.67, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.04, 0.10, 0.11, 1.0);
uniform vec4 dawn_rim_color : source_color = vec4(0.98, 0.74, 0.42, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float rim_strength : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float alpha_scale : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float palette_steps : hint_range(8.0, 96.0, 1.0) = 32.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a * alpha_scale;
	if (alpha <= 0.001) {
		discard;
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(tex.rgb, tint_color.rgb * max(luma, 0.18), tint_strength);
	color = mix(color, color * shadow_color.rgb, shadow_strength * smoothstep(0.32, 0.96, UV.y));
	float rim = smoothstep(0.38, 1.0, UV.x) * (1.0 - smoothstep(0.0, 0.24, UV.y));
	color += dawn_rim_color.rgb * rim * rim_strength * alpha;
	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * palette_steps + vec3(0.5)) / palette_steps;
	COLOR = vec4(color, alpha);
}
