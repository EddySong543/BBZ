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
uniform float broken_reflection_amount : hint_range(0.0, 0.15, 0.005) = 0.0;
uniform float broken_reflection_coverage : hint_range(0.0, 0.5, 0.01) = 0.16;
uniform float broken_reflection_start : hint_range(0.0, 1.0, 0.01) = 0.48;
uniform float broken_reflection_end : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform float broken_reflection_segments : hint_range(16.0, 160.0, 1.0) = 96.0;
uniform float inner_bounce_amount : hint_range(0.0, 0.15, 0.005) = 0.0;
uniform float inner_bounce_direction : hint_range(-1.0, 1.0, 1.0) = 0.0;
uniform float inner_bounce_start : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float inner_bounce_vertical_start : hint_range(0.0, 1.0, 0.01) = 0.28;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash11(float value) {
	return fract(sin(value * 127.1 + 19.73) * 43758.5453);
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

	// A sparse, stationary reflection catches only short underside fragments.
	// The low continuous bounce above keeps the platform readable; this pass
	// avoids the rejected ruler-straight orange contact line.
	float reflection_band = smoothstep(
			broken_reflection_start,
			broken_reflection_start + 0.07,
			UV.y);
	reflection_band *= 1.0 - smoothstep(
			broken_reflection_end - 0.07,
			broken_reflection_end,
			UV.y);
	float reflection_segment = floor(UV.x * broken_reflection_segments);
	float reflection_gate = step(
			1.0 - broken_reflection_coverage,
			hash11(reflection_segment));
	float broken_reflection = reflection_band * reflection_gate;
	color += lava_bounce_color.rgb
			* broken_reflection_amount
			* broken_reflection
			* (1.0 - graded_luma * 0.82);

	// Foreground rocks use opposed material instances: the left asset warms on
	// its right edge and the right asset on its left edge, both facing the lake.
	float inner_coord = mix(
			1.0 - UV.x,
			UV.x,
			step(0.0, inner_bounce_direction));
	float inner_facing_bounce = smoothstep(
			inner_bounce_start, 1.0, inner_coord);
	inner_facing_bounce *= smoothstep(
			inner_bounce_vertical_start, 1.0, UV.y);
	color += lava_bounce_color.rgb
			* inner_bounce_amount
			* inner_facing_bounce
			* (1.0 - graded_luma * 0.86);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source.a)
			* node_modulate;
}
