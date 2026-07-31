shader_type canvas_item;
render_mode unshaded, blend_mix;

// Atmospheric grade for non-playable chains. It suppresses the source's dark
// outline and lets each copy occupy a distinct depth plane without blur.
uniform vec4 depth_tint : source_color = vec4(0.40, 0.45, 0.45, 1.0);
uniform vec4 atmosphere_color : source_color = vec4(0.60, 0.65, 0.64, 1.0);
uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float contrast : hint_range(0.4, 1.1, 0.01) = 0.68;
uniform float brightness : hint_range(0.6, 1.3, 0.01) = 1.0;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float atmosphere_strength : hint_range(0.0, 0.9, 0.01) = 0.48;
uniform float outline_lift : hint_range(0.0, 1.0, 0.01) = 0.64;
uniform float alpha_scale : hint_range(0.0, 1.0, 0.01) = 0.56;
uniform float edge_fade : hint_range(0.0, 0.12, 0.005) = 0.04;
uniform float palette_steps : hint_range(8.0, 64.0, 1.0) = 24.0;
uniform float repeat_x : hint_range(1.0, 6.0, 1.0) = 1.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	float repeats = max(floor(repeat_x + 0.5), 1.0);
	vec2 sample_uv = vec2(fract(UV.x * repeats), UV.y);
	vec4 tex = texture(TEXTURE, sample_uv);
	if (tex.a <= 0.001) {
		discard;
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(vec3(luma), tex.rgb, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;
	color = mix(
			color,
			depth_tint.rgb * mix(0.28, 1.0, luma),
			tint_strength);

	float dark_outline = 1.0 - smoothstep(0.12, 0.38, luma);
	float fog_mix = clamp(
			atmosphere_strength + dark_outline * outline_lift,
			0.0,
			0.92);
	color = mix(color, atmosphere_color.rgb, fog_mix);
	color = floor(
			clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)
	) / palette_steps;

	float span_fade = smoothstep(0.0, edge_fade, UV.x)
			* (1.0 - smoothstep(1.0 - edge_fade, 1.0, UV.x));
	float alpha = tex.a * alpha_scale * mix(0.72, 1.0, span_fade);
	COLOR = vec4(color, alpha) * node_modulate;
}
