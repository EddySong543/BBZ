shader_type canvas_item;
render_mode unshaded;

// Subtle shared grade for the three authored ridge copies behind Scene2's
// waterfall. This pass preserves source pixels and alpha exactly: it performs
// no neighborhood sampling, blur, palette replacement, or edge cleanup.
uniform float saturation : hint_range(0.75, 1.1, 0.01) = 0.92;
uniform float contrast : hint_range(0.85, 1.1, 0.01) = 0.97;
uniform float brightness : hint_range(0.9, 1.1, 0.005) = 0.995;
uniform vec4 atmosphere_color : source_color = vec4(0.52, 0.65, 0.67, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.2, 0.01) = 0.06;
uniform vec2 light_dir = vec2(1.0, -0.8);
uniform vec4 light_color : source_color = vec4(1.0, 0.88, 0.64, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.13, 0.25, 0.29, 1.0);
uniform float receiver_light_strength : hint_range(0.0, 0.3, 0.01) = 0.10;
uniform float receiver_shadow_strength : hint_range(0.0, 0.2, 0.01) = 0.035;
uniform float receiver_rim_strength : hint_range(0.0, 0.4, 0.01) = 0.10;
uniform float receiver_rim_width : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform vec2 scene_light_source_uv = vec2(0.90, -0.08);
uniform vec2 scene_light_target_uv = vec2(0.47, 0.78);
uniform float scene_light_top_width : hint_range(0.02, 0.3, 0.01) = 0.10;
uniform float scene_light_bottom_width : hint_range(0.1, 0.6, 0.01) = 0.40;
uniform vec2 scene_light_pool_center = vec2(0.63, 0.28);
uniform vec2 scene_light_pool_radius = vec2(0.56, 0.40);

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
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
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luma), source.rgb, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	graded *= brightness;
	graded = mix(graded, atmosphere_color.rgb, atmosphere_strength);
	vec2 direction = normalize(light_dir);
	float facing = scene2_light_field(SCREEN_UV);
	float plane = pow(clamp(luma, 0.0, 1.0), 0.44);
	float light_mask = plane * facing;
	float shadow_mask = (1.0 - facing) * (1.0 - plane * 0.5);
	graded *= 1.0 + light_mask * receiver_light_strength;
	graded += light_color.rgb * light_mask * receiver_light_strength * 0.14;
	graded = mix(
			graded,
			graded * shadow_color.rgb,
			shadow_mask * receiver_shadow_strength);
	float toward_light_alpha = texture(
			TEXTURE,
			UV + direction * TEXTURE_PIXEL_SIZE * receiver_rim_width).a;
	float light_rim = max(source.a - toward_light_alpha, 0.0);
	graded += light_color.rgb * light_rim * receiver_rim_strength;
	COLOR = vec4(
			clamp(graded, vec3(0.0), vec3(1.0)),
			source.a) * node_modulate;
}
