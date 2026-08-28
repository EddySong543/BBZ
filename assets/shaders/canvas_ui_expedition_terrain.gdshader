shader_type canvas_item;
render_mode blend_mix;

// 远征地图上方的永久未知图纸。
// 未探索区由不透明的像素制图纸面替换实景；地图数据仍逐格记录，但最终揭图
// 轮廓由连续八方向可见度场生成，不能看出单格贴片。
// map_data: R=遮挡格，G=已清雾，B=散开起始时刻，A=保留。
uniform sampler2D map_data : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(18.0, 14.0);
uniform float cell_px = 107.0;
uniform float anim_time = 0.0;
uniform float seed_f = 0.0;

uniform vec4 paper_low_color : source_color = vec4(0.816, 0.706, 0.486, 1.0);
uniform vec4 paper_high_color : source_color = vec4(0.898, 0.827, 0.620, 1.0);
uniform vec4 paper_ink_color : source_color = vec4(0.353, 0.259, 0.184, 1.0);
uniform vec4 paper_edge_color : source_color = vec4(0.231, 0.169, 0.141, 1.0);
uniform float unseen_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float reveal_duration : hint_range(0.2, 0.8) = 0.46;
uniform float contour_steps_per_cell : hint_range(4.0, 16.0) = 8.0;
uniform float paper_grain_scale : hint_range(0.08, 0.28) = 0.16;
uniform float paper_crosshatch_steps : hint_range(4.0, 16.0) = 8.0;


float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}


float value_noise(vec2 position) {
	vec2 base = floor(position);
	vec2 local = fract(position);
	vec2 blend = local * local * (vec2(3.0) - 2.0 * local);
	float top = mix(hash21(base), hash21(base + vec2(1.0, 0.0)), blend.x);
	float bottom = mix(
			hash21(base + vec2(0.0, 1.0)),
			hash21(base + vec2(1.0, 1.0)), blend.x);
	return mix(top, bottom, blend.y);
}


// 两个静态低频层形成跨越数格的纸张明暗；不使用单格局部坐标或逐格色块。
float paper_grain(vec2 position) {
	float broad = value_noise(position);
	float folded = value_noise(position * 1.91 + vec2(7.3, 2.8));
	return broad * 0.68 + folded * 0.32;
}


// 低频噪声的等值线被压成粗像素墨线，表达“尚未测绘”，不描摹真实地形。
float cartographic_contour(vec2 position, float grain) {
	float broad_shape = value_noise(position * 0.43 + vec2(11.2, 3.7));
	float contour_phase = fract(grain * 2.7 + broad_shape * 1.35);
	float distance_to_line = min(contour_phase, 1.0 - contour_phase);
	return 1.0 - smoothstep(0.028, 0.075, distance_to_line);
}


// 排线仅在少量大片区域出现，保持图纸感而不铺成高频网格。
float paper_crosshatch(vec2 position) {
	vec2 ink_pixel = floor(position * paper_crosshatch_steps);
	float slash = 1.0 - step(1.0, mod(ink_pixel.x + ink_pixel.y * 2.0, 17.0));
	float backslash = 1.0 - step(
			1.0, mod(ink_pixel.x * 2.0 - ink_pixel.y + 37.0, 23.0));
	float sparse_region = smoothstep(
			0.62, 0.79, value_noise(position * 0.12 + vec2(23.1, 5.4)));
	return max(slash, backslash * 0.72) * sparse_region;
}


vec4 map_sample(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid_size.x || cell.y >= grid_size.y) {
		return vec4(0.0);
	}
	return texture(map_data, (cell + vec2(0.5)) / grid_size);
}


float reveal_started_at(vec2 cell) {
	return map_sample(cell).b;
}


float sample_visibility(vec2 cell) {
	vec4 data = map_sample(cell);
	if (data.g < 0.5) {
		return 0.0;
	}
	float reveal_age = max(anim_time - reveal_started_at(cell), 0.0);
	return smoothstep(0.0, reveal_duration, reveal_age);
}


// 双线性主体消除格间硬切；四个斜向样本补足八方向轮廓，让相邻清雾印章连成云湾。
float sample_continuous_visibility(vec2 grid_position) {
	vec2 centered_position = grid_position - vec2(0.5);
	vec2 base = floor(centered_position);
	vec2 local = fract(centered_position);
	vec2 blend = local * local * (vec2(3.0) - 2.0 * local);
	float top = mix(
			sample_visibility(base),
			sample_visibility(base + vec2(1.0, 0.0)), blend.x);
	float bottom = mix(
			sample_visibility(base + vec2(0.0, 1.0)),
			sample_visibility(base + vec2(1.0, 1.0)), blend.x);
	float bilinear_visibility = mix(top, bottom, blend.y);

	vec2 nearest_cell = floor(grid_position);
	float cardinal_visibility = max(max(
			sample_visibility(nearest_cell + vec2(-1.0, 0.0)),
			sample_visibility(nearest_cell + vec2(1.0, 0.0))), max(
			sample_visibility(nearest_cell + vec2(0.0, -1.0)),
			sample_visibility(nearest_cell + vec2(0.0, 1.0))));
	float diagonal_visibility = max(max(
			sample_visibility(nearest_cell + vec2(-1.0, -1.0)),
			sample_visibility(nearest_cell + vec2(1.0, -1.0))), max(
			sample_visibility(nearest_cell + vec2(-1.0, 1.0)),
			sample_visibility(nearest_cell + vec2(1.0, 1.0))));
	float neighbor_support = max(cardinal_visibility * 0.16, diagonal_visibility * 0.10);
	return clamp(max(bilinear_visibility, neighbor_support), 0.0, 1.0);
}


void fragment() {
	vec2 grid_position = UV * grid_size;
	// 所有纸纹和边界固定在地图空间；镜头移动时不会漂移或产生屏幕噪声。
	vec2 quantized_grid_position = (
			floor(grid_position * contour_steps_per_cell) + vec2(0.5)
			) / contour_steps_per_cell;
	float visibility = sample_continuous_visibility(quantized_grid_position);

	vec2 paper_position = quantized_grid_position + vec2(seed_f * 0.19, seed_f * 0.13);
	float grain = paper_grain(paper_position * paper_grain_scale);
	float edge_distortion = (paper_grain(paper_position * 0.23 + vec2(3.7)) - 0.5) * 0.14;
	float paper_shape = 1.0 - smoothstep(
			0.11 + edge_distortion, 0.73 + edge_distortion, visibility);

	float cartographic_contour_line = cartographic_contour(paper_position, grain);
	float crosshatch = paper_crosshatch(paper_position);
	float stipple = step(0.945, hash21(floor(paper_position * 8.0) + vec2(seed_f)));
	vec3 paper_color = mix(
			paper_low_color.rgb, paper_high_color.rgb,
			smoothstep(0.16, 0.86, grain));
	float printed_ink = clamp(
			cartographic_contour_line * 0.24 + crosshatch * 0.11 + stipple * 0.07,
			0.0, 0.32);
	paper_color = mix(paper_color, paper_ink_color.rgb, printed_ink);

	// 墨边只沿已探索区与未知图纸的连续交界出现，不沿每个逻辑格描边。
	float ink_edge = smoothstep(0.04, 0.22, visibility) * (
			1.0 - smoothstep(0.34, 0.66, visibility));
	paper_color = mix(paper_color, paper_edge_color.rgb, ink_edge * 0.82);
	float paper_alpha = clamp(unseen_alpha * paper_shape + ink_edge * 0.08, 0.0, 1.0);
	COLOR = vec4(paper_color, paper_alpha);
}
