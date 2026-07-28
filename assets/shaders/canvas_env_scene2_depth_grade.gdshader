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
// Optional Scene1-style receiver lighting. Defaults preserve every existing
// depth material; Scene2 enables it only on surfaces that face the sun.
uniform vec2 light_dir = vec2(1.0, -0.8);
uniform vec4 light_color : source_color = vec4(1.0, 0.88, 0.62, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.16, 0.29, 0.30, 1.0);
uniform float receiver_light_strength : hint_range(0.0, 0.4, 0.01) = 0.0;
uniform float receiver_shadow_strength : hint_range(0.0, 0.3, 0.01) = 0.0;
uniform float receiver_rim_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform float receiver_rim_width : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform vec2 scene_light_source_uv = vec2(0.90, -0.08);
uniform vec2 scene_light_target_uv = vec2(0.47, 0.78);
uniform float scene_light_top_width : hint_range(0.02, 0.3, 0.01) = 0.10;
uniform float scene_light_bottom_width : hint_range(0.1, 0.6, 0.01) = 0.40;
uniform vec2 scene_light_pool_center = vec2(0.63, 0.28);
uniform vec2 scene_light_pool_radius = vec2(0.56, 0.40);


float scene2_light_field(vec2 screen_uv) {
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

	// Like Scene1's roof shader, brighter authored planes receive most of the
	// added light while dark cracks remain dark. A low opposite-side tint
	// supplies volume without applying a gray wash.
	vec2 direction = normalize(light_dir);
	float facing = scene2_light_field(SCREEN_UV);
	float authored_plane = pow(clamp(luma, 0.0, 1.0), 0.42);
	float light_mask = authored_plane * facing;
	float shadow_mask = (1.0 - facing) * (1.0 - authored_plane * 0.45);
	col *= 1.0 + light_mask * receiver_light_strength;
	col += light_color.rgb * light_mask * receiver_light_strength * 0.16;
	col = mix(
			col,
			col * shadow_color.rgb,
			shadow_mask * receiver_shadow_strength);

	vec2 rim_offset = direction * TEXTURE_PIXEL_SIZE * receiver_rim_width;
	float toward_light_alpha = texture(TEXTURE, UV + rim_offset).a;
	float light_rim = max(tex.a - toward_light_alpha, 0.0);
	col += light_color.rgb * light_rim * receiver_rim_strength;
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), cleaned_alpha) * COLOR;
}
