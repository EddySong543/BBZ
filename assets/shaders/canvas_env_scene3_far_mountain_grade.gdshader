shader_type canvas_item;
render_mode unshaded, blend_mix;

// Rebuild the source image from luminance so its authored deep-blue hue cannot
// survive. These colors bridge Scene3's neutral cliffs and pale left mountain.
uniform vec4 shadow_palette : source_color = vec4(0.18, 0.21, 0.20, 1.0);
uniform vec4 midtone_palette : source_color = vec4(0.39, 0.44, 0.41, 1.0);
uniform vec4 highlight_palette : source_color = vec4(0.64, 0.69, 0.64, 1.0);
uniform float palette_midpoint : hint_range(0.25, 0.75, 0.01) = 0.46;
uniform float contrast : hint_range(0.5, 1.4, 0.01) = 0.92;
uniform float brightness : hint_range(0.5, 1.4, 0.01) = 1.12;
uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 atmosphere_color : source_color = vec4(0.57, 0.60, 0.57, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.6, 0.01) = 0.24;
uniform vec4 horizon_warm_color : source_color = vec4(0.89, 0.63, 0.47, 1.0);
uniform float horizon_warm_strength : hint_range(0.0, 0.5, 0.01) = 0.26;
uniform float horizon_warm_start : hint_range(0.0, 1.0, 0.01) = 0.48;
uniform float horizon_warm_end : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform float horizon_warm_center_x : hint_range(0.0, 1.0, 0.01) = 0.51;
uniform float horizon_warm_half_width : hint_range(0.1, 1.0, 0.01) = 0.76;
uniform float edge_cleanup_strength : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float edge_cleanup_luma_min : hint_range(0.0, 1.0, 0.01) = 0.88;
uniform float palette_steps : hint_range(8.0, 64.0, 1.0) = 32.0;


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		discard;
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float graded_luma = clamp(
			(luma - 0.5) * contrast + 0.5,
			0.0,
			1.0);
	float low_mix = smoothstep(0.0, palette_midpoint, graded_luma);
	float high_mix = smoothstep(palette_midpoint, 1.0, graded_luma);
	vec3 color = mix(shadow_palette.rgb, midtone_palette.rgb, low_mix);
	color = mix(color, highlight_palette.rgb, high_mix);
	color *= brightness;
	color = mix(color, atmosphere_color.rgb, atmosphere_strength);

	float horizon_vertical = smoothstep(
			horizon_warm_start,
			max(horizon_warm_end, horizon_warm_start + 0.001),
			SCREEN_UV.y);
	float horizon_distance = abs(SCREEN_UV.x - horizon_warm_center_x);
	float horizon_horizontal = 1.0 - smoothstep(
			horizon_warm_half_width,
			horizon_warm_half_width + 0.16,
			horizon_distance);
	color = mix(
			color,
			horizon_warm_color.rgb,
			horizon_vertical * horizon_horizontal * horizon_warm_strength);

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
	color = floor(
			clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)
	) / palette_steps;
	COLOR = vec4(color, cleaned_alpha) * COLOR;
}
