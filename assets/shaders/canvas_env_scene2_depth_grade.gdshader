shader_type canvas_item;

// Scene2 raster depth grade. Pixel density and palette reduction happen offline;
// this pass only controls atmosphere, saturation and contrast without blurring edges.

uniform float saturation : hint_range(0.0, 1.25, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.25, 0.01) = 1.0;
uniform float brightness : hint_range(0.5, 1.25, 0.01) = 1.0;
uniform vec4 atmosphere_color : source_color = vec4(0.62, 0.73, 0.73, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform vec2 quiet_center = vec2(0.5);
uniform vec2 quiet_radius = vec2(0.2);
uniform float quiet_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 quiet_color : source_color = vec4(0.72, 0.76, 0.72, 1.0);
uniform float quiet_saturation : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float quiet_contrast : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float quiet_lift : hint_range(0.0, 0.2, 0.01) = 0.0;
uniform float edge_cleanup_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge_cleanup_luma_min : hint_range(0.0, 1.0, 0.01) = 0.74;


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float neighbor_alpha = min(
			min(
					texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a,
					texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a),
			min(
					texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a,
					texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a));
	float exposed_edge = 1.0 - step(0.5, neighbor_alpha);
	float pale_edge = smoothstep(
			edge_cleanup_luma_min,
			min(edge_cleanup_luma_min + 0.06, 1.0),
			luma);
	float cleaned_alpha = tex.a * (
			1.0 - exposed_edge * pale_edge * edge_cleanup_strength);
	vec3 col = mix(vec3(luma), tex.rgb, saturation);
	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	col *= brightness;
	col = mix(col, atmosphere_color.rgb, atmosphere_strength);

	// Quantize the mask coordinate to the source texel so the grade cannot split
	// one logical pixel into differently colored screen pixels after exact 2x scaling.
	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	vec2 quiet_delta = (pixel_uv - quiet_center) / max(quiet_radius, vec2(0.001));
	float quiet_mask = (1.0 - smoothstep(0.72, 1.0, length(quiet_delta))) * quiet_strength;
	float quiet_luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 quiet_col = mix(vec3(quiet_luma), col, quiet_saturation);
	quiet_col = mix(quiet_color.rgb, quiet_col, quiet_contrast) + vec3(quiet_lift);
	col = mix(col, quiet_col, quiet_mask);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), cleaned_alpha) * COLOR;
}
