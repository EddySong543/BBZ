shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 horizon_color : source_color = vec4(0.37, 0.42, 0.43, 1.0);
uniform vec4 middle_color : source_color = vec4(0.52, 0.58, 0.57, 1.0);
uniform vec4 foreground_color : source_color = vec4(0.63, 0.68, 0.65, 1.0);
uniform vec4 cool_gleam : source_color = vec4(0.82, 0.88, 0.89, 1.0);
uniform float horizon_y : hint_range(0.0, 1.0, 0.001) = 0.325;
uniform float foreground_y : hint_range(0.0, 1.0, 0.001) = 0.74;
uniform float horizon_feather : hint_range(0.0, 0.15, 0.001) = 0.055;
uniform float broad_wave_strength : hint_range(0.0, 0.3, 0.005) = 0.055;
uniform float fine_breakup_strength : hint_range(0.0, 0.2, 0.005) = 0.055;
uniform float grass_grain_strength : hint_range(0.0, 0.3, 0.005) = 0.09;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_speed : hint_range(0.0, 4.0, 0.01) = 0.72;
uniform float broad_time_scale : hint_range(0.0, 1.0, 0.01) = 0.17;

float value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local = fract(position);
	local = local * local * (3.0 - 2.0 * local);
	float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float blade_layer(vec2 pixel, vec2 screen_pixel_size,
		float horizon_pixels, float depth, float spacing_scale, float seed) {
	float row_spacing = mix(6.0, 22.0, depth) * spacing_scale;
	float relative_y = max(pixel.y - horizon_pixels, 0.0);
	float row_id = floor(relative_y / row_spacing) + 1.0;
	float root_y = horizon_pixels + row_id * row_spacing;
	float height_from_root = root_y - pixel.y;
	float root_depth = clamp(
		(root_y * screen_pixel_size.y - horizon_y)
		/ max(foreground_y - horizon_y, 0.001), 0.0, 1.0);
	float cell_width = mix(3.5, 12.0, root_depth) * spacing_scale;
	float gust = sin(TIME * wind_speed + row_id * 0.71 + seed * 5.3)
		* mix(0.45, 2.4, root_depth);
	float shifted_x = pixel.x
		+ height_from_root * mix(0.13, 0.28, root_depth)
		+ gust * height_from_root / max(row_spacing, 1.0);
	float cell_id = floor(shifted_x / cell_width);
	float random_height = value_noise(vec2(
		cell_id * 0.47 + seed * 19.0,
		row_id * 0.61 + seed * 7.0));
	float height_limit = row_spacing * mix(0.70, 1.46, random_height);
	float center_distance = abs(fract(shifted_x / cell_width) - 0.5)
		* cell_width;
	float blade_width = mix(0.48, 1.28, root_depth);
	float line = 1.0 - smoothstep(
		blade_width, blade_width + 0.9, center_distance);
	float height_mask = step(0.0, height_from_root)
		* (1.0 - step(height_limit, height_from_root));
	float tip_taper = 1.0 - smoothstep(
		height_limit * 0.76, height_limit, height_from_root);
	return line * height_mask * tip_taper;
}

void fragment() {
	vec4 vertex_color = COLOR;
	float depth = smoothstep(horizon_y, foreground_y, SCREEN_UV.y);
	vec3 base = mix(horizon_color.rgb, middle_color.rgb, smoothstep(0.0, 0.58, depth));
	base = mix(base, foreground_color.rgb, smoothstep(0.50, 1.0, depth));

	vec2 broad_position = vec2(
		SCREEN_UV.x * 3.4 - wind_direction.x * TIME * wind_speed * broad_time_scale,
		SCREEN_UV.y * 5.2 - wind_direction.y * TIME * wind_speed * broad_time_scale);
	float broad_wave = value_noise(broad_position) * 2.0 - 1.0;
	float fine_breakup = value_noise(
		SCREEN_UV * vec2(17.0, 25.0)
		- wind_direction * TIME * wind_speed * broad_time_scale * 1.9) * 2.0 - 1.0;
	float moving_gleam = smoothstep(0.38, 0.86,
		value_noise(SCREEN_UV * vec2(5.5, 7.0)
		- wind_direction * TIME * wind_speed * broad_time_scale * 0.72));

	base *= 1.0 + broad_wave * broad_wave_strength;
	base *= 1.0 + fine_breakup * fine_breakup_strength * mix(0.2, 1.0, depth);
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float horizon_pixels = horizon_y / SCREEN_PIXEL_SIZE.y;
	float blades = blade_layer(pixel, SCREEN_PIXEL_SIZE, horizon_pixels + 2.0,
		depth, 1.0, 0.17);
	blades = max(blades, blade_layer(pixel, SCREEN_PIXEL_SIZE, horizon_pixels + 5.0,
		depth, 0.72, 0.61) * 0.72);
	vec3 blade_color = mix(middle_color.rgb, cool_gleam.rgb,
		mix(0.28, 0.62, depth));
	base = mix(base, blade_color, blades * mix(0.24, 0.44, depth));
	float row_frequency = mix(215.0, 92.0, depth);
	float row_index = floor((SCREEN_UV.y - horizon_y) * row_frequency);
	float blade_noise = value_noise(vec2(
		floor(SCREEN_UV.x * mix(260.0, 118.0, depth)) * 0.37,
		row_index * 0.41));
	float blade_grain = smoothstep(0.73, 0.98, blade_noise)
		* smoothstep(0.0, 0.16, depth);
	base = mix(base, cool_gleam.rgb,
		blade_grain * grass_grain_strength * mix(0.25, 1.0, depth));
	base = mix(base, cool_gleam.rgb, moving_gleam * 0.055 * mix(0.2, 1.0, depth));
	float horizon_alpha = smoothstep(horizon_y, horizon_y + horizon_feather, SCREEN_UV.y);
	COLOR = vec4(base * vertex_color.rgb, vertex_color.a * horizon_alpha);
}
