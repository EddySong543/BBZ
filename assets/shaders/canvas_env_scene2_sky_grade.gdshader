shader_type canvas_item;
render_mode unshaded;

uniform vec4 zenith_wash : source_color = vec4(0.56, 0.72, 0.79, 1.0);
uniform vec4 horizon_wash : source_color = vec4(0.74, 0.82, 0.83, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 0.6;
uniform float wash_strength : hint_range(0.0, 1.0) = 0.32;
uniform float contrast : hint_range(0.5, 1.5) = 0.86;
uniform float lift : hint_range(-0.25, 0.25) = 0.07;
uniform float palette_steps : hint_range(8.0, 128.0) = 48.0;
uniform vec4 scene_light_color : source_color = vec4(1.0, 0.89, 0.68, 1.0);
uniform vec4 scene_shadow_color : source_color = vec4(0.20, 0.35, 0.40, 1.0);
uniform float scene_light_strength : hint_range(0.0, 0.4, 0.01) = 0.0;
uniform float scene_shadow_strength : hint_range(0.0, 0.4, 0.01) = 0.0;
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
	float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(vec3(luminance), tex.rgb, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5 + lift);
	vec3 wash = mix(
		zenith_wash.rgb,
		horizon_wash.rgb,
		smoothstep(0.08, 0.82, UV.y)
	);
	color = mix(color, wash, wash_strength);
	float lower_horizon = smoothstep(0.68, 0.9, UV.y);
	color = mix(color, horizon_wash.rgb, lower_horizon * 0.72);
	float light_field = scene2_light_field(SCREEN_UV);
	color *= 1.0 + light_field * scene_light_strength;
	color += scene_light_color.rgb * light_field * scene_light_strength * 0.12;
	color = mix(
			color,
			color * scene_shadow_color.rgb,
			(1.0 - light_field) * scene_shadow_strength);
	color = floor(clamp(color, vec3(0.0), vec3(1.0)) * palette_steps + vec3(0.5)) / palette_steps;
	COLOR = vec4(color, tex.a);
}
