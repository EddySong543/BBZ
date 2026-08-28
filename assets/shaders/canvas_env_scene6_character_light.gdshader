shader_type canvas_item;
render_mode unshaded;

// Scene6-only character composite grade. The whole sprite is brought into the
// bright forge valley with smoke-plum shadows, burnt-bronze midtones and
// ash-gold highlights. Every term is stable across time and animation frames.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.72, 0.66, 0.60, 1.0);
uniform float flash_peak_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float flash_dark_response : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float source_saturation : hint_range(0.8, 1.3, 0.01) = 1.0;
uniform float source_contrast : hint_range(0.8, 1.3, 0.01) = 1.03;
uniform float scene_exposure : hint_range(0.5, 1.3, 0.01) = 0.97;
uniform float highlight_compression : hint_range(0.0, 0.5, 0.01) = 0.10;

// CharacterDisplay's shared interface remains available, but the scene rejects
// its animated contour pulse. Both rim controls are hard-capped to zero.
uniform vec2 light_dir = vec2(0.72, 0.68);
uniform float backlight : hint_range(0.0, 1.0) = 0.15;
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.68, 0.80, 1.0);
uniform vec4 skin_warmth : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.78, 0.72, 0.60, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.0;
uniform float rim_strength_cap : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform float rim_width : hint_range(1.0, 8.0) = 1.0;

// Continuous luma-based scene palette. Saturated authored colors keep more of
// their identity, but never bypass the environmental grade entirely.
uniform vec4 scene_grade_shadow : source_color = vec4(0.34, 0.34, 0.42, 1.0);
uniform vec4 scene_grade_mid : source_color = vec4(0.58, 0.52, 0.46, 1.0);
uniform vec4 scene_grade_highlight : source_color = vec4(0.76, 0.70, 0.58, 1.0);
uniform float scene_grade_amount : hint_range(0.0, 1.0, 0.01) = 0.70;
uniform float scene_value_amount : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float scene_identity_floor : hint_range(0.0, 1.0, 0.01) = 0.70;

// A broad oval pseudo-normal supplies restrained body volume without sampling
// the moving silhouette. P1/P2 only mirror light_dir.
uniform vec2 form_center = vec2(0.5, 0.48);
uniform vec2 form_roundness = vec2(0.42, 0.52);
uniform float form_depth : hint_range(0.2, 1.5, 0.01) = 0.82;
uniform float shadow_hue_amount : hint_range(0.0, 0.5, 0.01) = 0.22;

// Distant lava adds a wide, low dark-gold reflection instead of a red glow.
uniform vec4 lava_bounce_color : source_color = vec4(0.82, 0.67, 0.36, 1.0);
uniform float lava_bounce_amount : hint_range(0.0, 0.6, 0.01) = 0.26;
uniform float lava_bounce_luma_lift : hint_range(0.0, 0.25, 0.005) = 0.035;
uniform float lava_bounce_start : hint_range(0.3, 0.9, 0.01) = 0.54;
uniform float lava_bounce_softness : hint_range(0.08, 0.5, 0.01) = 0.34;

const vec3 LUMA_WEIGHTS = vec3(0.299, 0.587, 0.114);

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
	vec3 shifted = match_luma(color * tint, source_luma);
	return mix(color, shifted, clamp(amount, 0.0, 1.0));
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
	color = mix(vec3(source_luma), color, source_saturation);
	color = (color - vec3(0.5)) * source_contrast + vec3(0.5);
	color = clamp(color, vec3(0.0), vec3(1.0));
	color *= scene_exposure;
	color /= vec3(1.0) + color * highlight_compression;

	// Build the scene palette continuously from value, then multiply it into
	// the authored color so red, green and blue heroes retain their main hue.
	float luma = color_luma(color);
	float shadow_to_mid = smoothstep(0.08, 0.52, luma);
	float mid_to_high = smoothstep(0.46, 0.88, luma);
	vec3 scene_palette = mix(
			scene_grade_shadow.rgb,
			scene_grade_mid.rgb,
			shadow_to_mid);
	scene_palette = mix(scene_palette, scene_grade_highlight.rgb, mid_to_high);
	float mapped_luma = 0.025 + luma * 0.75;
	float graded_luma = mix(luma, mapped_luma, scene_value_amount);
	vec3 scene_target = match_luma(color * scene_palette, graded_luma);
	float source_chroma = max(color.r, max(color.g, color.b))
			- min(color.r, min(color.g, color.b));
	float identity_weight = clamp(source_chroma * 1.5, 0.0, 1.0);
	float grade_weight = scene_grade_amount
			* mix(1.0, scene_identity_floor, identity_weight);
	color = mix(color, scene_target, grade_weight);

	// The body-volume pass only shapes the recessed side. There is no bright
	// key or neighboring-alpha contour, so idle silhouettes cannot flash red.
	vec2 form_position = (UV - form_center)
			/ max(form_roundness, vec2(0.001));
	vec3 form_normal = normalize(vec3(
			form_position.x,
			form_position.y,
			form_depth));
	vec3 form_light_direction = normalize(vec3(
			direction.x,
			direction.y,
			0.28));
	float form_facing = dot(form_normal, form_light_direction) * 0.5 + 0.5;
	form_facing = smoothstep(0.18, 0.82, form_facing);
	float shadow_mask = 1.0 - form_facing;
	color = preserve_luma_tint(
			color,
			shadow_tint.rgb,
			shadow_hue_amount * shadow_mask);
	color *= 1.0 - backlight * shadow_mask;

	float bounce_end = min(lava_bounce_start + lava_bounce_softness, 1.0);
	float lower_body = smoothstep(lava_bounce_start, bounce_end, UV.y);
	vec3 lower_light_direction = normalize(vec3(
			direction.x * 0.30,
			1.0,
			0.24));
	float lower_facing = dot(form_normal, lower_light_direction) * 0.5 + 0.5;
	lower_facing = smoothstep(0.24, 0.80, lower_facing);
	float bounce_mask = lower_body * (0.45 + lower_facing * 0.55);
	luma = color_luma(color);
	float bounce_luma = min(
			luma + lava_bounce_luma_lift * (1.0 - luma),
			0.82);
	vec3 bounce_target = match_luma(
			color * lava_bounce_color.rgb,
			bounce_luma);
	color = mix(color, bounce_target, lava_bounce_amount * bounce_mask);

	// Keep the shared flash API inert in Scene6; battle feedback still uses the
	// established motion and impact effects without a full-body color peak.
	luma = color_luma(color);
	float flash_response = mix(
			flash_dark_response,
			1.0,
			smoothstep(0.12, 0.55, luma));
	float stable_flash = clamp(flash_amount, 0.0, 1.0)
			* flash_peak_strength
			* flash_response;
	color = mix(color, flash_color.rgb, stable_flash);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha)
			* node_modulate;
}
