shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 tint_color : source_color = vec4(0.58, 0.56, 0.53, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.20, 0.20, 0.19, 1.0);
uniform vec4 dawn_rim_color : source_color = vec4(0.98, 0.68, 0.43, 1.0);
uniform vec4 fog_color : source_color = vec4(0.64, 0.63, 0.61, 1.0);
uniform float saturation : hint_range(0.0, 1.25, 0.01) = 0.55;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.20;
uniform float rim_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float fog_strength : hint_range(0.0, 0.6, 0.01) = 0.22;
uniform float exposure : hint_range(0.6, 1.5, 0.01) = 1.18;
uniform float midtone_lift : hint_range(0.0, 0.2, 0.005) = 0.075;
uniform float alpha_scale : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float palette_steps : hint_range(8.0, 96.0, 1.0) = 32.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		discard;
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(vec3(luma), tex.rgb, saturation);
	vec3 color = mix(
			desaturated,
			tint_color.rgb * max(luma, 0.18),
			tint_strength);
	color = mix(
			color,
			fog_color.rgb,
			fog_strength * smoothstep(0.1, 0.9, UV.y));
	color = mix(
			color,
			color * shadow_color.rgb,
			shadow_strength * smoothstep(0.24, 1.0, UV.y));
	float midtone = smoothstep(0.08, 0.58, luma)
			* (1.0 - smoothstep(0.78, 1.0, luma));
	color = color * exposure + fog_color.rgb * midtone_lift * midtone;
	float rim = smoothstep(0.42, 1.0, UV.x)
			* (1.0 - smoothstep(0.0, 0.30, UV.y));
	color += dawn_rim_color.rgb * rim * rim_strength * tex.a;
	color = floor(
			clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)) / palette_steps;
	COLOR = vec4(
			color * node_modulate.rgb,
			tex.a * alpha_scale * node_modulate.a);
}
