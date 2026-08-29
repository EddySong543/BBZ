shader_type canvas_item;
render_mode unshaded;

// Scene8-only far-depth integration. The imported silhouette and alpha remain
// authoritative; only chroma, contrast and local sky light change with depth.
// This is intentionally a per-layer aerial perspective, not a full-screen fog.
uniform vec4 sky_tint : source_color = vec4(0.055, 0.17, 0.265, 1.0);
uniform vec4 aurora_tint : source_color = vec4(0.07, 0.40, 0.33, 1.0);
uniform float distance_mix : hint_range(0.0, 0.65, 0.01) = 0.25;
uniform float contrast_retention : hint_range(0.5, 1.1, 0.01) = 0.85;
uniform float saturation_retention : hint_range(0.45, 1.1, 0.01) = 0.85;
uniform float brightness : hint_range(0.6, 1.15, 0.01) = 0.95;
uniform float visibility_lift : hint_range(0.0, 0.18, 0.005) = 0.04;
uniform float upper_air_bias : hint_range(0.0, 1.0, 0.01) = 0.70;
uniform float aurora_bounce : hint_range(0.0, 0.18, 0.005) = 0.05;
uniform float palette_steps : hint_range(16.0, 128.0, 1.0) = 96.0;
uniform float edge_sky_mix : hint_range(0.0, 0.35, 0.01) = 0.16;
uniform float edge_aurora_mix : hint_range(0.0, 0.18, 0.005) = 0.045;


float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}


void fragment() {
	// Nearest source-pixel sampling preserves the imported pixel silhouette.
	vec2 source_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5))
			* TEXTURE_PIXEL_SIZE;
	vec4 source = texture(TEXTURE, source_uv);
	float source_luma = luminance(source.rgb);
	float alpha_up_1 = texture(
			TEXTURE,
			source_uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
	float alpha_up_2 = texture(
			TEXTURE,
			source_uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a;
	float alpha_up_3 = texture(
			TEXTURE,
			source_uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a;
	float silhouette_air = source.a * max(
			1.0 - alpha_up_1,
			max((1.0 - alpha_up_2) * 0.64,
					(1.0 - alpha_up_3) * 0.34));

	vec3 color = mix(vec3(source_luma), source.rgb, saturation_retention);
	color = vec3(source_luma) + (color - vec3(source_luma)) * contrast_retention;
	color *= brightness;

	// Mountain tops share more sky air while their lower mass remains readable.
	// This avoids a uniform grey wash and keeps the shoreline attached to water.
	float upper_air = 1.0 - smoothstep(0.08, 0.92, UV.y);
	float local_air = distance_mix * mix(1.0, upper_air, upper_air_bias);
	float visible_luma = clamp(
			source_luma * brightness + visibility_lift * local_air,
			0.0,
			0.92);
	vec3 sky_shifted = mix(color, sky_tint.rgb, local_air);
	float shifted_luma = luminance(sky_shifted);
	color = sky_shifted * (visible_luma / max(shifted_luma, 0.001));

	// Aurora light is a restrained upper-plane bounce, strongest on authored
	// highlights. It connects the far assets to the sky without painting them green.
	float highlight_receiver = smoothstep(0.22, 0.78, source_luma);
	float aurora_receiver = upper_air * mix(0.35, 1.0, highlight_receiver);
	vec3 aurora_shifted = mix(
			color,
			aurora_tint.rgb,
			aurora_receiver * aurora_bounce);
	float aurora_luma = luminance(aurora_shifted);
	color = aurora_shifted * (visible_luma / max(aurora_luma, 0.001));

	// Blend only the first few opaque source pixels below the top silhouette.
	// Alpha never changes, so overlapping authored mountains remain opaque.
	vec3 edge_sky = mix(
			color, sky_tint.rgb,
			silhouette_air * edge_sky_mix);
	float edge_sky_luma = luminance(edge_sky);
	color = edge_sky * (visible_luma / max(edge_sky_luma, 0.001));
	vec3 edge_aurora = mix(
			color, aurora_tint.rgb,
			silhouette_air * upper_air * edge_aurora_mix);
	float edge_aurora_luma = luminance(edge_aurora);
	color = edge_aurora * (
			visible_luma / max(edge_aurora_luma, 0.001));

	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * palette_steps + 0.5)
			/ palette_steps;
	// Never fade far assets: transparent grading makes overlapping mountains
	// show through one another and destroys the authored composition.
	COLOR = vec4(color, source.a);
}
