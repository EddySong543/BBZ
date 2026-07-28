shader_type canvas_item;
render_mode unshaded;

// Dedicated grade for the single authored mountain behind Scene2's waterfall.
// It intentionally does not share the former waterfall-bank material: the
// source is treated as a distant, solid mountain with a restrained pixel-value
// structure rather than as a cutout hugging either water edge.
uniform vec4 shadow_color : source_color = vec4(0.18, 0.29, 0.33, 1.0);
uniform vec4 middle_color : source_color = vec4(0.29, 0.41, 0.43, 1.0);
uniform vec4 light_color : source_color = vec4(0.44, 0.54, 0.53, 1.0);
uniform vec4 atmosphere_color : source_color = vec4(0.50, 0.61, 0.60, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.6, 0.01) = 0.12;
uniform float lower_haze_strength : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float source_detail_strength : hint_range(0.0, 0.6, 0.01) = 0.18;
uniform float structure_sample_radius_px : hint_range(0.0, 4.0, 0.25) = 1.5;
uniform float value_steps : hint_range(3.0, 8.0, 1.0) = 5.0;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 sample_offset = TEXTURE_PIXEL_SIZE * structure_sample_radius_px;
	float source_luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec4 source_right = texture(
			TEXTURE, UV + vec2(sample_offset.x, 0.0));
	vec4 source_left = texture(
			TEXTURE, UV - vec2(sample_offset.x, 0.0));
	vec4 source_lower = texture(
			TEXTURE, UV + vec2(0.0, sample_offset.y));
	vec4 source_upper = texture(
			TEXTURE, UV - vec2(0.0, sample_offset.y));
	float luma_right = dot(
			source_right.rgb,
			vec3(0.299, 0.587, 0.114));
	float luma_left = dot(
			source_left.rgb,
			vec3(0.299, 0.587, 0.114));
	float luma_lower = dot(
			source_lower.rgb,
			vec3(0.299, 0.587, 0.114));
	float luma_upper = dot(
			source_upper.rgb,
			vec3(0.299, 0.587, 0.114));
	float sample_weight = max(
			source.a * 2.0
			+ source_right.a
			+ source_left.a
			+ source_lower.a
			+ source_upper.a,
			0.001);
	float broad_luma = (
			source_luma * source.a * 2.0
			+ luma_right * source_right.a
			+ luma_left * source_left.a
			+ luma_lower * source_lower.a
			+ luma_upper * source_upper.a
	) / sample_weight;

	float steps = max(value_steps - 1.0, 1.0);
	float stepped_luma = floor(clamp(broad_luma, 0.0, 1.0) * steps + 0.5)
			/ steps;
	vec3 graded = mix(
			shadow_color.rgb,
			middle_color.rgb,
			smoothstep(0.08, 0.54, stepped_luma));
	graded = mix(
			graded,
			light_color.rgb,
			smoothstep(0.50, 0.94, stepped_luma));

	// Keep only a small amount of local relief so the authored ridge still
	// reads as stone without competing with the foreground mountains.
	float local_relief = (source_luma - broad_luma) * source_detail_strength;
	graded = clamp(graded + vec3(local_relief), vec3(0.0), vec3(1.0));
	float haze = clamp(
			atmosphere_strength
			+ smoothstep(0.28, 1.0, UV.y) * lower_haze_strength,
			0.0,
			0.85);
	graded = mix(graded, atmosphere_color.rgb, haze);

	COLOR = vec4(
			graded * node_modulate.rgb,
			source.a * opacity * node_modulate.a);
}
