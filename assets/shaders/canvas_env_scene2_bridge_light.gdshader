shader_type canvas_item;
render_mode unshaded;

// Scene2 bridge receiver, following Scene1's rooftop rule: illuminate authored
// stone planes, not transparent space or dark masonry gaps. The right-side tree
// casts a broad pixel-stepped cool shadow over the deck.
uniform vec2 light_dir = vec2(1.0, -0.8);
uniform vec4 light_color : source_color = vec4(1.0, 0.86, 0.58, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.16, 0.27, 0.27, 1.0);
uniform float receiver_light_strength : hint_range(0.0, 0.4, 0.01) = 0.14;
uniform float receiver_shadow_strength : hint_range(0.0, 0.3, 0.01) = 0.075;
uniform vec2 light_patch_center = vec2(0.50, 0.30);
uniform vec2 light_patch_radius = vec2(0.30, 0.20);
uniform vec2 tree_shadow_center = vec2(0.79, 0.34);
uniform vec2 tree_shadow_radius = vec2(0.24, 0.24);
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform vec2 scene_light_source_uv = vec2(0.90, -0.08);
uniform vec2 scene_light_target_uv = vec2(0.47, 0.78);
uniform float scene_light_top_width : hint_range(0.02, 0.3, 0.01) = 0.10;
uniform float scene_light_bottom_width : hint_range(0.1, 0.6, 0.01) = 0.40;
uniform vec2 scene_light_pool_center = vec2(0.63, 0.28);
uniform vec2 scene_light_pool_radius = vec2(0.56, 0.40);
uniform float grass_highlight_reduction : hint_range(0.0, 1.0, 0.01) = 0.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float stepped_ellipse(vec2 uv, vec2 center, vec2 radius) {
	vec2 delta = (uv - center) / max(radius, vec2(0.001));
	float distance_squared = dot(delta, delta);
	return 1.0 - smoothstep(
			0.62,
			1.0,
			floor(distance_squared * 10.0 + 0.5) / 10.0);
}


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
	vec4 source = texture(TEXTURE, UV);
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel_uv = (
			floor(UV * source_size / pixel_size) * pixel_size
			+ vec2(pixel_size * 0.5)) / source_size;
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float authored_plane = pow(clamp(luma, 0.0, 1.0), 0.38);
	float top_plane = 1.0 - smoothstep(0.34, 0.72, pixel_uv.y);
	float light_patch = scene2_light_field(SCREEN_UV);
	float tree_shadow = stepped_ellipse(
			pixel_uv, tree_shadow_center, tree_shadow_radius);

	float light_mask = authored_plane * top_plane * light_patch;
	float field_shadow = (1.0 - light_patch)
			* mix(0.55, 1.0, 1.0 - authored_plane);
	float tree_shadow_mask = tree_shadow
			* mix(0.35, 1.0, 1.0 - authored_plane);
	float shadow_mask = max(field_shadow, tree_shadow_mask) * source.a;
	vec3 col = source.rgb;
	col *= 1.0 + light_mask * receiver_light_strength;
	col += light_color.rgb * light_mask * receiver_light_strength * 0.16;
	col = mix(
			col,
			col * shadow_color.rgb,
			shadow_mask * receiver_shadow_strength);

	vec2 direction = normalize(light_dir);
	float toward_light_alpha = texture(
			TEXTURE,
			UV + direction * TEXTURE_PIXEL_SIZE).a;
	float rim = max(source.a - toward_light_alpha, 0.0) * top_plane;
	col += light_color.rgb * rim * receiver_light_strength * 0.38;
	float lit_luma = dot(col, vec3(0.299, 0.587, 0.114));
	float green_dominance = max(col.g - max(col.r, col.b), 0.0);
	float grass_highlight = smoothstep(0.05, 0.22, green_dominance)
			* smoothstep(0.38, 0.72, lit_luma);
	vec3 quieter_grass = mix(vec3(lit_luma), col, 0.82) * 0.95;
	col = mix(
			col,
			quieter_grass,
			grass_highlight * grass_highlight_reduction);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), source.a) * node_modulate;
}
