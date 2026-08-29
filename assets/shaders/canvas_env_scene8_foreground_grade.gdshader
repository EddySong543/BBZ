shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene8 foreground integration. The source palette remains dominant; a weak
// polar-night map only links shadows and snow highlights to the shared sky.
uniform vec4 shadow_palette : source_color = vec4(0.045, 0.09, 0.16, 1.0);
uniform vec4 middle_palette : source_color = vec4(0.13, 0.25, 0.38, 1.0);
uniform vec4 snow_palette : source_color = vec4(0.52, 0.68, 0.78, 1.0);
uniform vec4 aurora_tint : source_color = vec4(0.12, 0.44, 0.36, 1.0);
uniform float brightness : hint_range(0.4, 1.0, 0.01) = 0.92;
uniform float saturation_retention : hint_range(0.0, 1.2, 0.01) = 0.92;
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float snow_threshold : hint_range(0.1, 0.9, 0.01) = 0.48;
uniform float snow_softness : hint_range(0.05, 0.5, 0.01) = 0.24;
uniform float snow_retention : hint_range(0.0, 1.0, 0.01) = 0.70;
uniform float lower_depth_strength : hint_range(0.0, 0.4, 0.01) = 0.06;
uniform float aurora_response : hint_range(0.0, 0.3, 0.01) = 0.045;
uniform float palette_steps : hint_range(24.0, 160.0, 1.0) = 96.0;


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec4 source_up = texture(
			TEXTURE, clamp(UV - vec2(0.0, texel.y), vec2(0.0), vec2(1.0)));
	float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float up_luma = dot(source_up.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 retained_color = mix(vec3(luma), source.rgb, saturation_retention);
	retained_color *= brightness;

	float snow_mask = smoothstep(
			snow_threshold - snow_softness,
			snow_threshold + snow_softness,
			luma);
	float middle_mix = smoothstep(0.08, 0.52, luma);
	vec3 mapped = mix(shadow_palette.rgb, middle_palette.rgb, middle_mix);
	mapped = mix(mapped, snow_palette.rgb, snow_mask);
	vec3 color = mix(retained_color, mapped, palette_strength);
	color = mix(color, max(color, source.rgb * brightness),
			snow_mask * snow_retention * 0.34);

	// Keep the lower mass dark, but leave the upper snow planes readable.
	float lower_depth = smoothstep(0.42, 1.0, UV.y) * lower_depth_strength;
	color *= 1.0 - lower_depth * (1.0 - snow_mask * 0.48);
	float top_silhouette = source.a
			* (1.0 - step(0.03, source_up.a));
	float upward_relief = clamp((luma - up_luma) * 3.0, 0.0, 1.0);
	float upper_exposure = 1.0 - smoothstep(0.32, 0.82, UV.y);
	float aurora_mask = snow_mask * upper_exposure
			* clamp(top_silhouette + upward_relief * 0.42, 0.0, 1.0);
	color = mix(color, max(color, aurora_tint.rgb),
			aurora_mask * aurora_response);

	color = floor(clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + 0.5) / palette_steps;
	COLOR = vec4(color, source.a);
}
