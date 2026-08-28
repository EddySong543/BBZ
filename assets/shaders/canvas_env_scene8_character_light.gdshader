shader_type canvas_item;
render_mode unshaded;

// Scene8-only character grade. The authored palette remains identifiable, but
// the whole sprite sits in deep blue night. A broad cyan-green key comes from
// above while violet lake bounce stays on the lower shadow side. The aurora
// phase changes hue very slowly and preserves luminance, so it cannot flash.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float source_saturation : hint_range(0.8, 1.2, 0.01) = 0.98;
uniform float source_contrast : hint_range(0.8, 1.2, 0.01) = 1.04;
uniform float scene_exposure : hint_range(0.6, 1.1, 0.01) = 0.90;
uniform float highlight_compression : hint_range(0.0, 0.4, 0.01) = 0.08;

// CharacterDisplay's mature light and hit-feedback interface.
uniform vec2 light_dir = vec2(0.42, -1.0);
uniform float backlight : hint_range(0.0, 1.0) = 0.20;
uniform vec4 shadow_tint : source_color = vec4(0.26, 0.36, 0.62, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.02, 1.0, 0.97, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.015;
uniform float warm_identity_protection : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform vec4 fill_color : source_color = vec4(0.28, 0.72, 0.82, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.025;
uniform vec4 rim_color : source_color = vec4(0.36, 1.0, 0.76, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform float rim_width : hint_range(1.0, 4.0) = 1.0;

uniform vec4 night_shadow_color : source_color = vec4(0.22, 0.30, 0.52, 1.0);
uniform vec4 night_mid_color : source_color = vec4(0.46, 0.60, 0.76, 1.0);
uniform float night_grade_amount : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform float night_value_scale : hint_range(0.7, 1.0, 0.01) = 0.90;
uniform float scene_identity_floor : hint_range(0.0, 1.0, 0.01) = 0.78;

uniform vec4 aurora_green : source_color = vec4(0.30, 1.0, 0.64, 1.0);
uniform vec4 aurora_cyan : source_color = vec4(0.28, 0.82, 1.0, 1.0);
uniform float aurora_key_amount : hint_range(0.0, 0.5, 0.01) = 0.24;
uniform float aurora_key_luma_lift : hint_range(0.0, 0.12, 0.005) = 0.035;
uniform vec4 aurora_violet : source_color = vec4(0.72, 0.46, 1.0, 1.0);
uniform float violet_bounce_amount : hint_range(0.0, 0.4, 0.01) = 0.13;
uniform float violet_bounce_start : hint_range(0.35, 0.85, 0.01) = 0.56;
uniform float aurora_cycle_sec : hint_range(12.0, 60.0, 0.5) = 28.0;
uniform float aurora_flow_amount : hint_range(0.0, 0.3, 0.01) = 0.12;

const vec3 LUMA_WEIGHTS = vec3(0.299, 0.587, 0.114);
const float FULL_CIRCLE = 6.28318530718;

varying vec4 node_modulate;


float color_luma(vec3 color) {
	return dot(color, LUMA_WEIGHTS);
}


vec3 match_luma(vec3 tint, float reference_luma) {
	float tint_luma = max(color_luma(tint), 0.001);
	vec3 matched = clamp(
			tint * reference_luma / tint_luma,
			vec3(0.0),
			vec3(1.0));
	float correction = reference_luma - color_luma(matched);
	return clamp(matched + vec3(correction), vec3(0.0), vec3(1.0));
}


vec3 preserve_luma_tint(vec3 color, vec3 tint, float amount) {
	float source_luma = color_luma(color);
	vec3 target = match_luma(color * tint, source_luma);
	return mix(color, target, clamp(amount, 0.0, 1.0));
}


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 color = source.rgb;
	float alpha = source.a;
	vec2 direction = normalize(light_dir);

	float source_luma = color_luma(color);
	float source_chroma = max(color.r, max(color.g, color.b))
			- min(color.r, min(color.g, color.b));
	float identity_weight = clamp(source_chroma * 3.0, 0.0, 1.0);
	color = mix(vec3(source_luma), color, source_saturation);
	color = clamp(
			(color - vec3(0.5)) * source_contrast + vec3(0.5),
			vec3(0.0),
			vec3(1.0));
	color *= scene_exposure;
	color /= vec3(1.0) + color * highlight_compression;

	float luma = color_luma(color);
	vec3 night_palette = mix(
			night_shadow_color.rgb,
			night_mid_color.rgb,
			smoothstep(0.12, 0.76, luma));
	float night_weight = night_grade_amount
			* mix(1.0, scene_identity_floor, identity_weight);
	color = preserve_luma_tint(color, night_palette, night_weight);
	color *= mix(1.0, night_value_scale, night_grade_amount);

	float directional_sample = dot(UV - vec2(0.5), direction);
	float light_side = smoothstep(-0.28, 0.34, directional_sample);
	float shadow_side = 1.0 - smoothstep(-0.34, 0.04, directional_sample);
	color = preserve_luma_tint(
			color,
			shadow_tint.rgb,
			backlight * shadow_side);
	color *= 1.0 - backlight * shadow_side * 0.16;
	color = mix(color, color * skin_warmth.rgb, warmth_amount);

	float current_luma = color_luma(color);
	float dark_protection = 1.0 - current_luma * 0.72;
	color += fill_color.rgb
			* fill_amount
			* (0.58 + light_side * 0.22)
			* dark_protection;

	float aurora_phase = 0.5 + 0.5 * sin(
			TIME / max(aurora_cycle_sec, 0.001) * FULL_CIRCLE);
	float flow_offset = (aurora_phase - 0.5) * aurora_flow_amount * 2.0;
	float facing_coordinate = dot(
			UV - vec2(0.5),
			normalize(vec2(direction.x, 0.18)));
	float aurora_mix = clamp(
			0.50 + facing_coordinate * 0.34 + flow_offset,
			0.0,
			1.0);
	vec3 aurora_palette = mix(
			aurora_green.rgb,
			aurora_cyan.rgb,
			aurora_mix);
	float upper_body = 1.0 - smoothstep(0.16, 0.88, UV.y);
	float key_mask = light_side * (0.58 + upper_body * 0.42);
	current_luma = color_luma(color);
	float key_luma = min(
			current_luma
					+ aurora_key_luma_lift * (1.0 - current_luma),
			0.78);
	vec3 key_target = match_luma(color * aurora_palette, key_luma);
	float key_identity_guard = mix(1.0, 0.30, identity_weight);
	color = mix(
			color,
			key_target,
			aurora_key_amount * key_mask * key_identity_guard);

	float lower_body = smoothstep(violet_bounce_start, 0.96, UV.y);
	float bounce_mask = lower_body * (0.58 + shadow_side * 0.42);
	current_luma = color_luma(color);
	vec3 violet_target = match_luma(
			color * aurora_violet.rgb,
			min(current_luma + 0.018 * (1.0 - current_luma), 0.68));
	color = mix(
			color,
			violet_target,
			violet_bounce_amount
					* bounce_mask
					* mix(1.0, 0.42, identity_weight));

	// Bright warm authored colors (skin, pale cloth, gold) need their hue back
	// after the night grade. Match the already-darkened luminance, so this
	// restores identity without making the character look day-lit.
	float warm_source = smoothstep(
			0.035,
			0.16,
			source.r - max(source.g, source.b));
	float bright_source = smoothstep(0.42, 0.76, source_luma);
	float warm_identity_mask = warm_source * bright_source;
	current_luma = color_luma(color);
	vec3 warm_identity_target = match_luma(source.rgb, current_luma);
	color = mix(
			color,
			warm_identity_target,
			warm_identity_protection * warm_identity_mask);

	vec2 rim_offset = TEXTURE_PIXEL_SIZE * rim_width;
	float outside_alpha = texture(
			TEXTURE,
			UV + direction * rim_offset).a;
	float rim = clamp(alpha - outside_alpha, 0.0, 1.0);
	current_luma = color_luma(color);
	vec3 rim_target = match_luma(
			color * rim_color.rgb,
			min(current_luma + 0.05 * (1.0 - current_luma), 0.76));
	color = mix(color, rim_target, rim * rim_strength);

	color = mix(color, flash_color.rgb, flash_amount);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha)
			* node_modulate;
}
