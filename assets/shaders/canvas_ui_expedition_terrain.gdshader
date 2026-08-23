shader_type canvas_item;
render_mode blend_mix;

// 晴风稻田地表上方的永久探索迷雾。
// 迷雾固定在地图坐标中；角色走过时逐格驱散，离开后不会重新覆盖。
// map_data: R=遮挡格，G=已清雾，B=散开起始时刻，A=保留。
uniform sampler2D map_data : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(18.0, 14.0);
uniform float cell_px = 107.0;
uniform float anim_time = 0.0;
uniform float seed_f = 0.0;

uniform vec4 fog_low_color : source_color = vec4(0.839, 0.780, 0.635, 1.0);
uniform vec4 fog_high_color : source_color = vec4(0.961, 0.922, 0.824, 1.0);
uniform float unseen_alpha : hint_range(0.0, 1.0) = 0.93;
uniform float reveal_duration : hint_range(0.2, 0.8) = 0.46;
uniform float reveal_softness : hint_range(0.04, 0.24) = 0.12;
uniform float boundary_feather_cells : hint_range(0.04, 0.20) = 0.10;

float cleared_at(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid_size.x || cell.y >= grid_size.y) {
		return 0.0;
	}
	vec2 data_uv = (cell + vec2(0.5)) / grid_size;
	return step(0.5, texture(map_data, data_uv).g);
}

float reveal_started_at(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid_size.x || cell.y >= grid_size.y) {
		return 0.0;
	}
	vec2 data_uv = (cell + vec2(0.5)) / grid_size;
	return texture(map_data, data_uv).b;
}

float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}

void fragment() {
	vec2 grid_position = UV * grid_size;
	vec2 cell = floor(grid_position);
	vec2 cell_uv = fract(grid_position);
	float cleared = cleared_at(cell);

	// 新清除格按各自时间戳从格心向外散开；相邻格的时间错开，形成沿脚步扩散的波。
	float reveal_age = max(anim_time - reveal_started_at(cell), 0.0);
	float reveal_progress = smoothstep(0.0, reveal_duration, reveal_age);
	float local_noise = hash21(floor(grid_position * 8.0 + vec2(seed_f)));
	float local_threshold = clamp(
			length(cell_uv - vec2(0.5)) * 1.32 + (local_noise - 0.5) * 0.12,
			0.0, 1.0);
	float dispersed = 1.0 - smoothstep(
			reveal_progress * 1.20 - reveal_softness,
			reveal_progress * 1.20 + reveal_softness,
			local_threshold);

	// 只在尚未清除的一侧向外软化极窄边缘；不会把角色当前位置变成随身光圈。
	float nearest_cleared_edge = 2.0;
	if (cleared_at(cell + vec2(-1.0, 0.0)) > 0.5) {
		nearest_cleared_edge = min(nearest_cleared_edge, cell_uv.x);
	}
	if (cleared_at(cell + vec2(1.0, 0.0)) > 0.5) {
		nearest_cleared_edge = min(nearest_cleared_edge, 1.0 - cell_uv.x);
	}
	if (cleared_at(cell + vec2(0.0, -1.0)) > 0.5) {
		nearest_cleared_edge = min(nearest_cleared_edge, cell_uv.y);
	}
	if (cleared_at(cell + vec2(0.0, 1.0)) > 0.5) {
		nearest_cleared_edge = min(nearest_cleared_edge, 1.0 - cell_uv.y);
	}
	float boundary_feather = (1.0 - cleared) * 0.48 * (
			1.0 - smoothstep(0.0, boundary_feather_cells, nearest_cleared_edge));

	float cleared_amount = max(cleared * dispersed, boundary_feather);
	// 地图坐标中的暖雾缓慢交错流动。两层频率与方向不同，保持轻盈但不形成随身光圈。
	vec2 fog_drift = grid_position * vec2(0.61, 0.47);
	float cloud_a = 0.5 + 0.5 * sin(
			fog_drift.x + fog_drift.y * 0.72 + anim_time * 0.31 + seed_f);
	float cloud_b = 0.5 + 0.5 * sin(
			-fog_drift.x * 0.53 + fog_drift.y * 1.17 - anim_time * 0.19
			+ seed_f * 1.7);
	float cloud_mix = smoothstep(0.14, 0.88, cloud_a * 0.62 + cloud_b * 0.38);
	vec2 drifting_grain_cell = floor(
			(grid_position + vec2(anim_time * 0.10, -anim_time * 0.055)) * 6.0);
	float moving_grain = hash21(drifting_grain_cell + vec2(seed_f));
	float grain = (moving_grain - 0.5) * 0.026;
	float fog_alpha = clamp(
			(unseen_alpha + grain + (cloud_mix - 0.5) * 0.025)
			* (1.0 - cleared_amount),
			0.0, 0.97);
	vec3 warm_fog = mix(fog_low_color.rgb, fog_high_color.rgb, cloud_mix);
	COLOR = vec4(warm_fog * (0.985 + grain), fog_alpha);
}
