shader_type canvas_item;
render_mode unshaded;

// Scene3-only distant mountain grade. The source raster carries pale RGB in
// its antialiased edge texels; sampling darker opaque neighbors removes that
// contamination before atmospheric grading instead of drawing another rim.
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
uniform float edge_cleanup_strength : hint_range(0.0, 1.0, 0.01) = 0.90;
uniform float edge_cleanup_luma_min : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float edge_alpha_cutoff : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float edge_sample_px : hint_range(1.0, 3.0, 1.0) = 1.0;
uniform vec4 edge_tint_color : source_color = vec4(0.44, 0.48, 0.46, 1.0);
uniform float edge_tint_strength : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float edge_erode_strength : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform vec2 light_dir = vec2(1.0, -0.8);
uniform vec4 light_color : source_color = vec4(1.0, 0.88, 0.62, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.16, 0.29, 0.30, 1.0);
uniform float receiver_light_strength : hint_range(0.0, 0.4, 0.01) = 0.0;
uniform float receiver_shadow_strength : hint_range(0.0, 0.3, 0.01) = 0.0;
uniform float receiver_rim_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform float receiver_rim_width : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform vec4 horizon_warm_color : source_color = vec4(0.88, 0.56, 0.44, 1.0);
uniform float horizon_warm_strength : hint_range(0.0, 0.4, 0.01) = 0.0;
uniform float horizon_warm_start : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float horizon_warm_end : hint_range(0.0, 1.0, 0.01) = 0.9;
uniform float horizon_warm_center_x : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float horizon_warm_half_width : hint_range(0.1, 1.0, 0.01) = 0.7;
uniform vec2 scene_light_source_uv = vec2(0.90, -0.08);
uniform vec2 scene_light_target_uv = vec2(0.47, 0.78);
uniform float scene_light_top_width : hint_range(0.02, 0.3, 0.01) = 0.10;
uniform float scene_light_bottom_width : hint_range(0.1, 0.6, 0.01) = 0.40;
uniform vec2 scene_light_pool_center = vec2(0.63, 0.28);
uniform vec2 scene_light_pool_radius = vec2(0.56, 0.40);


float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}


float scene3_light_field(vec2 screen_uv) {
	vec2 grid = vec2(480.0, 270.0);
	vec2 suv = (floor(screen_uv * grid) + vec2(0.5)) / grid;
	vec2 axis = scene_light_target_uv - scene_light_source_uv;
	float raw_along = dot(suv - scene_light_source_uv, axis)
			/ max(dot(axis, axis), 0.0001);
	float along = clamp(raw_along, 0.0, 1.0);
	vec2 center = scene_light_source_uv + axis * along;
	vec2 normal = normalize(vec2(-axis.y, axis.x));
	float width = mix(scene_light_top_width, scene_light_bottom_width, along);
	float row_break = (
			fract(floor(suv.y * 72.0) * 0.6180339) - 0.5) * 0.014;
	float across = abs(dot(suv - center, normal));
	float cone = 1.0 - smoothstep(
			width + row_break,
			width + row_break + 0.045,
			across);
	float reach = smoothstep(-0.08, 0.04, raw_along)
			* (1.0 - smoothstep(0.86, 1.08, raw_along));
	vec2 pool_delta = (suv - scene_light_pool_center)
			/ max(scene_light_pool_radius, vec2(0.001));
	float upper_pool = 1.0 - smoothstep(0.70, 1.0, length(pool_delta));
	float field = max(cone * reach, upper_pool * 0.35);
	field *= 1.0 - smoothstep(0.78, 0.98, suv.y);
	return floor(clamp(field, 0.0, 1.0) * 4.0 + 0.5) / 4.0;
}


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 sample_step = TEXTURE_PIXEL_SIZE * edge_sample_px;
	vec4 left = texture(TEXTURE, UV - vec2(sample_step.x, 0.0));
	vec4 right = texture(TEXTURE, UV + vec2(sample_step.x, 0.0));
	vec4 up = texture(TEXTURE, UV - vec2(0.0, sample_step.y));
	vec4 down = texture(TEXTURE, UV + vec2(0.0, sample_step.y));

	float left_weight = left.a * (1.04 - luminance(left.rgb));
	float right_weight = right.a * (1.04 - luminance(right.rgb));
	float up_weight = up.a * (1.04 - luminance(up.rgb));
	float down_weight = down.a * (1.04 - luminance(down.rgb));
	float inner_weight = max(
			left_weight + right_weight + up_weight + down_weight,
			0.0001);
	vec3 inner_rgb = (
			left.rgb * left_weight
			+ right.rgb * right_weight
			+ up.rgb * up_weight
			+ down.rgb * down_weight) / inner_weight;

	float luma = luminance(tex.rgb);
	float neighbor_alpha = min(
			min(left.a, right.a),
			min(up.a, down.a));
	float exposed_edge = 1.0 - step(0.72, neighbor_alpha);
	float pale_edge = smoothstep(
			edge_cleanup_luma_min,
			min(edge_cleanup_luma_min + 0.12, 1.0),
			luma);
	float edge_contamination = exposed_edge * pale_edge
			* edge_cleanup_strength;
	vec3 source_rgb = mix(tex.rgb, inner_rgb, edge_contamination);
	float alpha_gate = smoothstep(
			edge_alpha_cutoff,
			min(edge_alpha_cutoff + 0.18, 1.0),
			tex.a);
	float cleaned_alpha = tex.a * mix(
			1.0,
			alpha_gate,
			edge_cleanup_strength * 0.72);
	cleaned_alpha *= 1.0
			- edge_contamination * edge_erode_strength;

	float source_luma = luminance(source_rgb);
	vec3 col = mix(vec3(source_luma), source_rgb, saturation);
	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	col *= brightness;
	col = mix(col, atmosphere_color.rgb, atmosphere_strength);

	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5))
			* TEXTURE_PIXEL_SIZE;
	vec2 quiet_delta = (pixel_uv - quiet_center)
			/ max(quiet_radius, vec2(0.001));
	float quiet_mask = (
			1.0 - smoothstep(0.72, 1.0, length(quiet_delta)))
			* quiet_strength;
	float quiet_luma_value = luminance(col);
	vec3 quiet_col = mix(
			vec3(quiet_luma_value),
			col,
			quiet_saturation);
	quiet_col = mix(quiet_color.rgb, quiet_col, quiet_contrast)
			+ vec3(quiet_lift);
	col = mix(col, quiet_col, quiet_mask);

	float facing = scene3_light_field(SCREEN_UV);
	float authored_plane = pow(clamp(source_luma, 0.0, 1.0), 0.42);
	float light_mask = authored_plane * facing;
	float shadow_mask = (1.0 - facing) * (1.0 - authored_plane * 0.45);
	col *= 1.0 + light_mask * receiver_light_strength;
	col += light_color.rgb * light_mask * receiver_light_strength * 0.16;
	col = mix(
			col,
			col * shadow_color.rgb,
			shadow_mask * receiver_shadow_strength);

	// Kept as an explicit opt-in parameter for material compatibility. Scene3
	// distant layers set it to zero so the silhouette cannot turn white again.
	vec2 direction = normalize(light_dir);
	vec2 rim_offset = direction * TEXTURE_PIXEL_SIZE * receiver_rim_width;
	float toward_light_alpha = texture(TEXTURE, UV + rim_offset).a;
	float light_rim = max(tex.a - toward_light_alpha, 0.0);
	col += light_color.rgb * light_rim * receiver_rim_strength;

	float horizon_vertical = smoothstep(
			horizon_warm_start,
			max(horizon_warm_end, horizon_warm_start + 0.001),
			SCREEN_UV.y);
	float horizon_distance = abs(SCREEN_UV.x - horizon_warm_center_x);
	float horizon_horizontal = 1.0 - smoothstep(
			horizon_warm_half_width,
			horizon_warm_half_width + 0.16,
			horizon_distance);
	float horizon_warmth = horizon_vertical * horizon_horizontal
			* horizon_warm_strength;
	col = mix(col, horizon_warm_color.rgb, horizon_warmth);
	col = mix(
			col,
			edge_tint_color.rgb,
			edge_contamination * edge_tint_strength);
	COLOR = vec4(
			clamp(col, vec3(0.0), vec3(1.0)),
			cleaned_alpha) * COLOR;
}
