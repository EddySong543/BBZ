shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 horizon_color : source_color = vec4(0.50, 0.60, 0.64, 1.0);
uniform vec4 far_color : source_color = vec4(0.58, 0.67, 0.68, 1.0);
uniform vec4 middle_color : source_color = vec4(0.66, 0.73, 0.72, 1.0);
uniform vec4 foreground_color : source_color = vec4(0.73, 0.78, 0.74, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.43, 0.53, 0.56, 1.0);
uniform vec4 cool_gleam : source_color = vec4(0.86, 0.90, 0.88, 1.0);
uniform float horizon_y : hint_range(0.0, 1.0, 0.001) = 0.325;
uniform float foreground_y : hint_range(0.0, 1.0, 0.001) = 0.74;
uniform float pixel_block_size : hint_range(1.0, 8.0, 1.0) = 4.0;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_speed : hint_range(0.0, 4.0, 0.01) = 0.72;
uniform float wind_fps : hint_range(1.0, 16.0, 1.0) = 8.0;

float hash_cell(vec2 cell) {
	return fract(sin(dot(floor(cell), vec2(127.1, 311.7))) * 43758.5453);
}

float pixel_blade_layer(vec2 cell, float horizon_cell, float depth,
		float wind_tick, float seed) {
	float row_spacing = floor(mix(2.0, 6.0, depth) + 0.5);
	float relative_y = max(cell.y - horizon_cell, 0.0);
	float row_id = floor(relative_y / row_spacing) + 1.0;
	float cell_width = floor(mix(2.0, 5.0, depth) + 0.5);
	float column_id = floor(cell.x / cell_width);
	float row_offset = floor(hash_cell(vec2(column_id + seed * 31.0,
		row_id + seed * 17.0)) * row_spacing);
	float root_y = horizon_cell + row_id * row_spacing
		+ row_offset - floor(row_spacing * 0.5);
	float blade_height = root_y - cell.y;
	float gust = floor(sin(wind_tick * wind_speed * 3.0
		+ row_id * 0.73 + seed * 5.0) * 1.25 + 0.5);
	float shifted_x = cell.x
		+ floor(blade_height * mix(0.18, 0.38, depth))
		+ gust * wind_direction.x * step(1.0, blade_height);
	float blade_id = floor(shifted_x / cell_width);
	float random_height = hash_cell(vec2(blade_id + seed * 23.0,
		row_id + seed * 11.0));
	float height_limit = 1.0 + floor(random_height * mix(2.0, 5.0, depth));
	float local_x = mod(shifted_x, cell_width);
	float one_cell_wide = 1.0 - step(1.0, local_x);
	float below_tip = 1.0 - step(height_limit + 1.0, blade_height);
	return one_cell_wide * step(0.0, blade_height) * below_tip;
}

void fragment() {
	vec2 screen_pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 pixel_cell = floor(screen_pixel / pixel_block_size);
	vec2 snapped_uv = (pixel_cell * pixel_block_size
		+ vec2(pixel_block_size * 0.5)) * SCREEN_PIXEL_SIZE;
	float depth = clamp((snapped_uv.y - horizon_y)
		/ max(foreground_y - horizon_y, 0.001), 0.0, 1.0);
	float depth_variation = (hash_cell(vec2(
		floor(pixel_cell.x / 5.0), floor(pixel_cell.y / 2.0))) - 0.5) * 0.14;
	float palette_depth = clamp(depth + depth_variation, 0.0, 1.0);
	vec3 base = horizon_color.rgb;
	base = mix(base, far_color.rgb, step(0.18, palette_depth));
	base = mix(base, middle_color.rgb, step(0.43, palette_depth));
	base = mix(base, foreground_color.rgb, step(0.72, palette_depth));

	float coarse_noise = hash_cell(vec2(
		floor(pixel_cell.x / mix(7.0, 3.0, depth)),
		floor(pixel_cell.y / mix(3.0, 2.0, depth))));
	base = mix(base, shadow_color.rgb, step(coarse_noise, 0.13) * 0.38);
	base = mix(base, cool_gleam.rgb, step(0.87, coarse_noise) * 0.28);

	float wind_tick = floor(TIME * wind_fps) / wind_fps;
	float horizon_cell = floor((horizon_y / SCREEN_PIXEL_SIZE.y)
		/ pixel_block_size);
	float blades = pixel_blade_layer(pixel_cell, horizon_cell,
		depth, wind_tick, 0.19);
	blades = max(blades, pixel_blade_layer(pixel_cell + vec2(1.0, 0.0),
		horizon_cell + 1.0, depth, wind_tick, 0.67) * 0.72);
	vec3 blade_color = mix(middle_color.rgb, cool_gleam.rgb,
		step(0.48, depth) * 0.52);
	float blade_weight = mix(0.40, 0.64, step(0.50, depth));
	base = mix(base, blade_color, blades * blade_weight);

	float horizon_alpha = step(horizon_y, snapped_uv.y);
	COLOR = vec4(base, horizon_alpha);
}
