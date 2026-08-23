shader_type canvas_item;
render_mode blend_mix, unshaded;

// 晴风稻田专用屏幕空间光影：两道斜向日照与一片缓慢漂移的云影。
// 只覆盖已被角色永久驱散的地图区域，避免未知区被光照泄露。
uniform sampler2D map_data : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(18.0, 14.0);
uniform vec2 view_size_px = vec2(1920.0, 1080.0);
uniform vec2 camera_world_origin_px = vec2(0.0);
uniform float cell_px = 120.0;
uniform float anim_time = 0.0;
uniform float pixel_step_px : hint_range(1.0, 8.0) = 4.0;
uniform vec3 sunlight_color : source_color = vec3(1.0, 0.79, 0.31);
uniform vec3 cloud_shadow_color : source_color = vec3(0.06, 0.19, 0.12);
uniform float sunlight_alpha : hint_range(0.0, 0.2) = 0.075;
uniform float cloud_shadow_alpha : hint_range(0.0, 0.2) = 0.085;


float soft_band(float value, float center, float half_width, float feather) {
	return 1.0 - smoothstep(half_width, half_width + feather, abs(value - center));
}


void fragment() {
	vec2 stepped_px = floor(UV * view_size_px / pixel_step_px) * pixel_step_px;
	vec2 stepped_uv = stepped_px / view_size_px;
	vec2 world_px = camera_world_origin_px + stepped_px;
	vec2 tile = clamp(floor(world_px / cell_px), vec2(0.0), grid_size - vec2(1.0));
	float cleared = step(0.5, texture(map_data, (tile + 0.5) / grid_size).g);

	float diagonal = stepped_uv.x * 0.74 + stepped_uv.y;
	float slow_sway = sin(anim_time * 0.075) * 0.026;
	float sun_a = soft_band(diagonal, 0.43 + slow_sway, 0.105, 0.09);
	float sun_b = soft_band(diagonal, 1.19 - slow_sway * 0.7, 0.14, 0.11);
	float sunlight = max(sun_a, sun_b) * (0.78 + stepped_uv.y * 0.22);

	float cloud_field = sin((stepped_uv.x * 0.72 + stepped_uv.y * 0.31 + anim_time * 0.006) * 6.2831853);
	cloud_field += sin((stepped_uv.x * -0.34 + stepped_uv.y * 0.58 - anim_time * 0.004) * 6.2831853) * 0.48;
	float cloud_shadow = smoothstep(0.72, 1.22, cloud_field) * (1.0 - sunlight * 0.55);

	float light_a = sunlight * sunlight_alpha * cleared;
	float shadow_a = cloud_shadow * cloud_shadow_alpha * cleared;
	float alpha = 1.0 - (1.0 - light_a) * (1.0 - shadow_a);
	vec3 color = sunlight_color;
	if (alpha > 0.0001) {
		color = (sunlight_color * light_a
				+ cloud_shadow_color * shadow_a * (1.0 - light_a)) / alpha;
	}
	COLOR = vec4(color, alpha);
}
