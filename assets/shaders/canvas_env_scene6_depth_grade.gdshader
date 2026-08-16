shader_type canvas_item;
render_mode unshaded;

// Shared Scene6 depth grade. Each environment layer owns an independent
// ShaderMaterial so distance roles remain editable without changing the PNG.
uniform float brightness : hint_range(0.3, 1.3, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.4, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.4, 0.01) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float highlight_rolloff : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 palette_shadow : source_color = vec4(0.055, 0.018, 0.035, 1.0);
uniform vec4 palette_mid : source_color = vec4(0.28, 0.07, 0.075, 1.0);
uniform vec4 palette_light : source_color = vec4(0.70, 0.20, 0.10, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float palette_source_dark : hint_range(0.0, 0.5, 0.01) = 0.03;
uniform float palette_source_light : hint_range(0.1, 1.0, 0.01) = 0.62;
uniform vec4 lava_bounce_color : source_color = vec4(1.0, 0.25, 0.06, 1.0);
uniform float lava_bounce_amount : hint_range(0.0, 0.25, 0.005) = 0.0;
uniform float lava_bounce_start : hint_range(0.0, 1.0, 0.01) = 0.58;

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
	float palette_value = clamp(
			(graded_luma - palette_source_dark)
			/ max(palette_source_light - palette_source_dark, 0.001),
			0.0,
			1.0);
	vec3 mapped_palette = mix(
			palette_shadow.rgb,
			palette_mid.rgb,
			smoothstep(0.0, 0.62, palette_value));
	mapped_palette = mix(
			mapped_palette,
			palette_light.rgb,
			smoothstep(0.56, 1.0, palette_value));
	color = mix(color, mapped_palette, palette_strength);

	float bounce = smoothstep(lava_bounce_start, 1.0, UV.y);
	bounce = floor(bounce * 4.0 + 0.5) / 4.0;
	graded_luma = dot(color, vec3(0.299, 0.587, 0.114));
	color += lava_bounce_color.rgb
			* lava_bounce_amount
			* bounce
			* (1.0 - graded_luma * 0.76);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source.a)
			* node_modulate;
}
