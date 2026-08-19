shader_type canvas_item;
render_mode blend_mix;

// 晴风稻田地表上方的当前视野迷雾。
// 地表本身始终由 GroundArtLayer 绘制；日照/云影由独立 AtmosphereLayer 负责。
// map_data: R=墙标记（保留接口），G=当前可见，B=进入视野时刻。
uniform sampler2D map_data : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(18.0, 14.0);
uniform float cell_px = 107.0;
uniform float anim_time = 0.0;
uniform float seed_f = 0.0;

uniform vec3 fog_base : source_color = vec3(0.028, 0.105, 0.073);
uniform float unseen_alpha : hint_range(0.0, 1.0) = 0.60;
uniform float vignette_alpha : hint_range(0.0, 0.5) = 0.14;
uniform float reveal_dur : hint_range(0.1, 1.5) = 0.32;
uniform vec2 vision_center_cell = vec2(9.5, 7.5);
uniform vec2 vision_logic_center_cell = vec2(9.5, 7.5);
uniform vec2 vision_half_extent_cells = vec2(6.0, 4.0);
uniform float vision_feather_cells : hint_range(0.08, 0.36) = 0.28;

float visible_at(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid_size.x || cell.y >= grid_size.y) {
		return 0.0;
	}
	vec2 data_uv = (cell + vec2(0.5)) / grid_size;
	return step(0.5, texture(map_data, data_uv).g);
}

void fragment() {
	vec2 grid_position = UV * grid_size;
	// 玩法mask已经落在新逻辑格；反向采样两中心的差值，让整块雾边从旧视觉格
	// 连续滑到新格。静止时两中心相等，采样严格回到原始tile mask。
	vec2 mask_position = grid_position
			+ vision_logic_center_cell
			- vision_center_cell;
	vec2 cell = floor(mask_position);
	vec2 cell_uv = fract(mask_position);
	float cell_visible = visible_at(cell);

	// 可见格始终完整保亮。只有当前格不可见时，才从相邻可见格的共享边
	// 向外铺一小段柔边；因此轮廓严格贴格且沿逻辑mask自然形成凹凸。
	float nearest_visible_edge = 2.0;
	if (visible_at(cell + vec2(-1.0, 0.0)) > 0.5) {
		nearest_visible_edge = min(nearest_visible_edge, cell_uv.x);
	}
	if (visible_at(cell + vec2(1.0, 0.0)) > 0.5) {
		nearest_visible_edge = min(nearest_visible_edge, 1.0 - cell_uv.x);
	}
	if (visible_at(cell + vec2(0.0, -1.0)) > 0.5) {
		nearest_visible_edge = min(nearest_visible_edge, cell_uv.y);
	}
	if (visible_at(cell + vec2(0.0, 1.0)) > 0.5) {
		nearest_visible_edge = min(nearest_visible_edge, 1.0 - cell_uv.y);
	}
	float boundary_feather = 1.0 - smoothstep(
			0.0, vision_feather_cells, nearest_visible_edge);
	float current_visible = max(cell_visible, boundary_feather);
	float unseen = 1.0 - current_visible;

	// 只保留轻微边缘压暗；明确光影在独立层统一覆盖麦穗与场景物体。
	vec2 vignette_delta = (SCREEN_UV - vec2(0.50)) * vec2(1.0, 0.94);
	float vignette = smoothstep(0.30, 0.72, length(vignette_delta));
	float dark_alpha = clamp(unseen * unseen_alpha + vignette * vignette_alpha, 0.0, 0.82);
	COLOR = vec4(fog_base, dark_alpha);
}
