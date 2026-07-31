shader_type canvas_item;

// Scene3 cloud sea: the stable pixel-cloud silhouette plus quantized vertical
// rolling and independent lobe growth. This file stays separate from Scene2.

// =============================================================
// canvas_env_dark_smoke.gdshader v5 — 屋脊雾旗 + 月光薄雾框（2026-07-10 稳定性修·Eddy 报竖线/孤块）
// 作者: Claude (Game Studios) ｜ 用途: scene1 战斗舞台氛围层
// 形态（v4 定稿·Eddy 过）：
//   mode_isolated=1 孤立雾旗：横向拉长·端头梯级拖尾·底平钉基线·顶缘脆亮月光缘·簇状分布
//   mode_isolated=0 连绵雾墙：keep=1 大旗搭接成整条 + 基线下实身·贴底循环=画框
//   常驻中央旗（pin_*）：钉 rect 固定位不随流·防开局中间空白
// v5 稳定性三修：
//   ① 半像素中心采样——所有边界比较用像素列/行中心值·根除浮点等号抖动（细竖线闪烁）
//   ② 嵌套端头拖尾——外子块只能比内子块先消失（同一随机数分档阈值）·根除孤立小方块
//   ③ 旗长下限抬高——保证拖尾后旗身仍有主体
// 全量（流动/缓漂/起伏/边界）整虚拟像素步进。零纹理采样。复杂度：低。
// =============================================================

uniform vec4 fill_color : source_color = vec4(0.045, 0.055, 0.085, 1.0);  // 雾体色
uniform vec4 lit_color : source_color = vec4(0.55, 0.66, 0.86, 1.0);      // 月光缘色（冷蓝·脆亮）
uniform float lit_strength : hint_range(0.0, 1.0) = 0.6;   // 月光缘强度
uniform float alpha_max : hint_range(0.0, 1.0) = 0.88;
uniform float flow_speed = 0.006;     // 整体流速（格/秒·整像素步进）
uniform float sway_speed = 0.18;      // 单旗缓漂相位速度
uniform float mode_isolated : hint_range(0.0, 1.0) = 1.0;  // 1=孤立雾旗 0=连绵雾墙（前景框）
uniform float cells = 10.0;           // x 向格数
uniform float keep : hint_range(0.0, 1.0) = 0.5;    // 簇保留率（雾墙配 1.0）
uniform float cloud_size : hint_range(0.3, 2.5) = 1.0;   // 旗长基数（格单位）
uniform float base_frac : hint_range(0.0, 1.0) = 0.49;   // 平底基线（rect 高度比例）
uniform float row_h = 0.041;          // 层高（格宽单位·旗=2 层）
uniform float edge_h = 0.022;         // 月光缘厚度（格宽单位·≈2 虚拟像素）
uniform float inner_contrast : hint_range(0.0, 0.6) = 0.15;  // F 体内两档明度流纹强度（0=平涂）
uniform float breath_amount : hint_range(0.0, 0.5) = 0.18;   // G 单旗透明度呼吸幅度（相位错开）
uniform float breath_speed = 0.3;     // G 呼吸速度
uniform float seed = 0.0;             // 层种子（⚠三层实例必须互异——否则簇分布层间相关一起空档）
uniform float aspect = 19.3;          // rect 宽高比 W/H
uniform vec2 pixel_grid = vec2(900.0, 47.0);   // 粗像素格（rect 尺寸/3px）


uniform float row_count : hint_range(2.0, 4.0, 1.0) = 2.0;
uniform float isolated_len_cap : hint_range(0.5, 2.5, 0.05) = 0.78;
uniform float isolated_forced_stride : hint_range(2.0, 4.0, 1.0) = 3.0;
uniform float isolated_break_stride : hint_range(0.0, 8.0, 1.0) = 0.0;
uniform float lobe_profile : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float lobe_height_scale : hint_range(0.35, 1.25, 0.05) = 1.0;
uniform float lobe_shape_variation : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform float lobe_min_step_px : hint_range(1.0, 3.0, 1.0) = 1.0;
uniform float continuous_bob_scale : hint_range(0.0, 0.8, 0.05) = 0.6;
uniform float pattern_offset = 0.0;
uniform float scene3_roll_amount : hint_range(0.0, 0.15, 0.005) = 0.0;
uniform float scene3_roll_speed : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float scene3_roll_scale : hint_range(0.5, 4.0, 0.05) = 1.0;
uniform float scene3_roll_phase : hint_range(0.0, 6.2832, 0.01) = 0.0;
uniform float scene3_billow_amount : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform float scene3_billow_speed : hint_range(0.0, 2.0, 0.01) = 0.0;
uniform float scene3_billow_phase : hint_range(0.0, 6.2832, 0.01) = 0.0;
uniform float bank_valley_center : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float bank_valley_width : hint_range(0.05, 0.5, 0.01) = 0.25;
uniform float bank_valley_depth : hint_range(0.0, 0.3, 0.01) = 0.0;
uniform float bank_valley_steps : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float bank_valley_peak_scale : hint_range(0.2, 1.0, 0.05) = 1.0;
uniform float bank_side_rise : hint_range(0.0, 0.25, 0.01) = 0.0;
uniform float bank_join_height : hint_range(0.0, 0.3, 0.01) = 0.0;
uniform float bank_join_variation : hint_range(0.0, 0.08, 0.005) = 0.0;
// Scene2-only reflected water light. Defaults to zero so Scene1's shared
// procedural clouds retain their established appearance.
uniform vec4 water_reflect_color : source_color = vec4(0.58, 0.73, 0.72, 1.0);
uniform float water_reflect_strength : hint_range(0.0, 0.35, 0.01) = 0.0;
uniform float water_reflect_center_x : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float water_reflect_half_width : hint_range(0.02, 0.4, 0.01) = 0.12;
uniform float water_reflect_edge_h : hint_range(0.005, 0.12, 0.005) = 0.03;
// Scene2 enables this receiver response; Scene1 materials keep both strengths
// at zero and therefore retain their established moonlit cloud appearance.
uniform vec2 directional_light_dir = vec2(1.0, -0.8);
uniform vec4 directional_light_color : source_color = vec4(1.0, 0.88, 0.68, 1.0);
uniform vec4 directional_shadow_color : source_color = vec4(0.24, 0.37, 0.38, 1.0);
uniform float directional_light_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform float directional_shadow_strength : hint_range(0.0, 0.3, 0.01) = 0.0;
uniform vec2 scene_light_source_uv = vec2(0.90, -0.08);
uniform vec2 scene_light_target_uv = vec2(0.47, 0.78);
uniform float scene_light_top_width : hint_range(0.02, 0.3, 0.01) = 0.10;
uniform float scene_light_bottom_width : hint_range(0.1, 0.6, 0.01) = 0.40;
uniform vec2 scene_light_pool_center = vec2(0.63, 0.28);
uniform vec2 scene_light_pool_radius = vec2(0.56, 0.40);
// Scene3-only local dawn lining. It uses the animated exposed top edge, so the
// warm light appears and disappears with the rolling cloud silhouette.
uniform vec2 local_sun_screen_pos = vec2(0.51, 0.796);
uniform vec2 local_sun_rim_radius = vec2(0.34, 0.24);
uniform vec4 local_sun_rim_color : source_color = vec4(1.0, 0.68, 0.42, 1.0);
uniform float local_sun_rim_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
float hash(vec2 p) {
	p = mod(p, 289.0);   // ⚠入口取模压量级——sid×31 级大数会让 sin 精度劣化·随机失真（碎齿率失控教训）
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float scene3_vertical_roll(float screen_u, float h_units, float t) {
	float broad = sin(
			screen_u * 6.2831853 * scene3_roll_scale
			+ t * scene3_roll_speed
			+ scene3_roll_phase);
	float folding = sin(
			screen_u * 6.2831853 * scene3_roll_scale * 2.13
			- t * scene3_roll_speed * 1.37
			+ scene3_roll_phase * 1.7);
	float raw_offset = (broad * 0.72 + folding * 0.28)
			* scene3_roll_amount * h_units;
	float qy = h_units / pixel_grid.y;
	return floor(raw_offset / qy + 0.5) * qy * (1.0 - mode_isolated);
}


float scene3_lobe_growth(float sid, float t) {
	float wave = sin(
			t * scene3_billow_speed
			+ sid * 0.41
			+ scene3_billow_phase);
	float stepped = floor((wave * 0.5 + 0.5) * 4.0 + 0.5) / 4.0;
	float signed_step = stepped * 2.0 - 1.0;
	return 1.0 + signed_step * scene3_billow_amount
			* (1.0 - mode_isolated);
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


// 单条雾旗的 2 层旗身（共用）：边界全对齐像素格；端头嵌套拖尾；顶层内区碎齿。
// cu_c 传入的是【像素列中心】坐标（半像素偏置·防浮点等号抖动）。
float banner_rows(float cu_c, float cv_c, float sid, float cx, float len, float base_v, float q) {
	float has = step(0.05, len);   // ⚠无旗（len=0）必须整体归零——最小宽度保底曾把空格撑成 4 列幽灵云（单格云病根）
	float c = 0.0;
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		float active_row = step(fk + 0.5, row_count);
		float w = max(floor(len * pow(0.58, fk) / q) * q, q * 4.0);   // 宽度对齐格·逐层收窄
		float x0 = floor((cx + fk * 0.1 * len - w * 0.5) / q) * q;
		float in_x = step(x0, cu_c) * step(cu_c, x0 + w);
		float y_bot = base_v - row_h * fk;
		float in_y = step(y_bot - row_h, cv_c) * step(cv_c, y_bot);
		// 嵌套端头拖尾：距端 0/1 子块用同一随机数分档阈值（0.75/0.35）→ 外块必先掉·永不留孤块
		float sub_id = floor((cu_c - x0) / 0.07);
		float n_sub = max(floor(w / 0.07), 1.0);
		float from_l = sub_id;
		float from_r = n_sub - 1.0 - sub_id;
		float edge_d = min(from_l, from_r);
		float side = step(from_r, from_l);   // 0=靠左端 1=靠右端（两端独立随机）
		float he = hash(vec2(sid * 31.0 + side * 999.0, 13.7 + fk));
		float erode_end = step(edge_d, 1.0) * step(he, mix(0.75, 0.35, edge_d));
		// 顶层碎齿：只挖内区（距端 ≥2 子块）→ 不与拖尾相邻成孤块
		float notch = fk * step(2.0, edge_d)
				* step(hash(vec2(sid * 17.0 + sub_id, 3.1)), 0.08);
		c = max(c, in_x * in_y
				* (1.0 - min(1.0, erode_end + notch)) * active_row);
	}
	return c * has;
}


// Scene2 可选云丘轮廓：保留 Scene1 的格点流动与分布，只把旗状矩形
// 换成宽底、阶梯化上缘。默认关闭，因此 Scene1 原有外观不受影响。
float lobe_rows(
		float cu_c,
		float cv_c,
		float cx,
		float len,
		float base_v,
		float q,
		float qy,
		float sid,
		float height_scale) {
	float has = step(0.05, len);
	float width = max(floor(len / q) * q, q * 6.0);
	float center = floor(cx / q) * q + q * 0.5;
	float half_width = max(width * 0.5, q * 3.0);
	float shape_q = q * max(lobe_min_step_px, 1.0);
	float shape_cu = floor(cu_c / shape_q) * shape_q + shape_q * 0.5;
	float nx = abs(shape_cu - center) / half_width;
	float variant = floor(hash(vec2(sid, 101.7)) * 3.0);
	float variant_a = 1.0 - step(0.5, variant);
	float variant_c = step(1.5, variant);
	float variant_b = 1.0 - variant_a - variant_c;
	float center_shift_variant = -0.16 * variant_a
			+ 0.02 * variant_b + 0.16 * variant_c;
	float center_shift = center_shift_variant * lobe_shape_variation;
	float left_shift = mix(
			mix(0.26, 0.4, hash(vec2(sid, 71.3))),
			0.24 * variant_a + 0.38 * variant_b + 0.3 * variant_c,
			lobe_shape_variation);
	float right_shift = mix(
			mix(0.24, 0.38, hash(vec2(sid, 83.1))),
			0.38 * variant_a + 0.27 * variant_b + 0.22 * variant_c,
			lobe_shape_variation);
	float left_width = mix(
			mix(0.3, 0.44, hash(vec2(sid, 17.9))),
			0.5 * variant_a + 0.31 * variant_b + 0.38 * variant_c,
			lobe_shape_variation);
	float right_width = mix(
			mix(0.3, 0.46, hash(vec2(sid, 29.7))),
			0.3 * variant_a + 0.42 * variant_b + 0.52 * variant_c,
			lobe_shape_variation);
	float left_nx = abs(
			shape_cu - (center - half_width * left_shift)
	) / (half_width * left_width);
	float right_nx = abs(
			shape_cu - (center + half_width * right_shift)
	) / (half_width * right_width);
	float center_width = mix(
			0.42,
			0.34 * variant_a + 0.5 * variant_b + 0.3 * variant_c,
			lobe_shape_variation);
	float center_nx = abs(
			shape_cu - (center + half_width * center_shift)
	) / (half_width * center_width);
	float main_arch = sqrt(max(1.0 - nx * nx, 0.0)) * 0.5;
	float center_arch = sqrt(max(1.0 - center_nx * center_nx, 0.0))
			* mix(
					mix(0.8, 0.96, hash(vec2(sid, 61.7))),
					0.68 * variant_a + 1.0 * variant_b + 0.76 * variant_c,
					lobe_shape_variation);
	float left_arch = sqrt(max(1.0 - left_nx * left_nx, 0.0))
			* mix(
					mix(0.74, 0.9, hash(vec2(sid, 37.5))),
					1.0 * variant_a + 0.62 * variant_b + 0.58 * variant_c,
					lobe_shape_variation);
	float right_arch = sqrt(max(1.0 - right_nx * right_nx, 0.0))
			* mix(
					mix(0.78, 0.98, hash(vec2(sid, 49.3))),
					0.58 * variant_a + 0.78 * variant_b + 1.0 * variant_c,
					lobe_shape_variation);
	float arch = max(max(main_arch, center_arch), max(left_arch, right_arch));
	arch *= mix(
			1.0,
			mix(0.78, 1.12, hash(vec2(sid, 113.9))),
			lobe_shape_variation);
	float arch_step = floor(arch * 16.0 + 0.5) / 16.0;
	float top_v = base_v - row_h * (
			0.12 + arch_step * 2.25 * height_scale);
	top_v = floor(top_v / qy) * qy;
	float inside_x = step(nx, 1.0);
	float inside_y = step(top_v, cv_c) * step(cv_c, base_v);
	return inside_x * inside_y * has;
}


// 流动雾旗（簇状分布 + 结构保底 + 呼吸 + 量化缓漂/起伏）。
float banner(
		float cu_c,
		float cv_c,
		float id,
		float t,
		float h_units,
		float base_offset) {
	float sid = id + seed * 97.0;
	float cluster_on = step(hash(vec2(floor(id / 3.0) + seed * 13.0, 41.7)), keep);
	// 结构保底：按材质设定的跨度必出一条旗（随流照滚）→ 屏幕中部任何时刻必有云。
	// （⚠常驻钉死旗方案已否——不随流的云读作"卡住"·2026-07-10 Eddy 报）
	float forced_stride = max(isolated_forced_stride, 2.0);
	float forced_phase = floor(forced_stride * 0.5);
	float forced = step(
			abs(mod(id, forced_stride) - forced_phase),
			0.01
	) * mode_isolated;
	float on = max(cluster_on * step(hash(vec2(sid, 5.13)), 0.85), forced);
	float break_enabled = step(1.5, isolated_break_stride) * mode_isolated;
	float break_stride = max(isolated_break_stride, 2.0);
	float scheduled_break = step(
			abs(mod(id + floor(seed), break_stride)),
			0.01
	) * break_enabled;
	on *= 1.0 - scheduled_break;
	// 旗长下限抬高（0.35→0.5·拖尾后仍有主体）·长短混排
	float len = cloud_size * (0.5 + 0.95 * hash(vec2(sid, 2.2))) * on;
	// 间隙保证（孤立模式·Eddy 2026-07-10）：旗长封顶 0.78 格 + 落位抖动只用剩余空隙的一半
	// → 相邻旗最小间隙 ≥0.18 格（~50-60px）·雾墙模式不封顶（要互相搭接成整条）
	len = min(len, mix(9.0, isolated_len_cap, mode_isolated));
	float q = cells / pixel_grid.x;
	float sway = floor(sin(t * sway_speed + id * 2.17) * 0.02 / q + 0.5) * q;
	float jit = (hash(vec2(sid, 9.7)) - 0.5)
			* mix(0.3, max(1.0 - len - 0.22, 0.0), mode_isolated);
	float cx = id + 0.5 + jit + sway;
	float qy = h_units / pixel_grid.y;
	float bob = floor(
			(1.0 - mode_isolated) * sin(t * 0.4 + id * 1.9)
					* row_h * continuous_bob_scale / qy + 0.5
	) * qy;
	float base_v = h_units * base_frac + bob + base_offset;
	float valley_ratio = clamp(
			base_offset / max(bank_valley_depth * h_units, 0.0001),
			0.0,
			1.0
	) * (1.0 - mode_isolated);
	float height_scale = lobe_height_scale * mix(
			1.0,
			bank_valley_peak_scale,
			valley_ratio);
	height_scale *= scene3_lobe_growth(sid, t);
	// 呼吸只给孤立旗——雾墙内旗互相搭接·各旗呼吸相位不同会在搭接边出"明暗脉动竖缝"（max 并集台阶）
	float breath = 1.0 - breath_amount * mode_isolated * (0.5 + 0.5 * sin(t * breath_speed + id * 2.9));
	float stepped_rows = banner_rows(cu_c, cv_c, sid, cx, len, base_v, q);
	float cloud_lobe = lobe_rows(
			cu_c, cv_c, cx, len, base_v, q, qy, sid, height_scale);
	return mix(stepped_rows, cloud_lobe, lobe_profile) * breath;
}


// 全场覆盖：邻格三旗取并；雾墙模式再并上基线以下连体实身。
float bank_valley_offset(float screen_u, float h_units) {
	float valley = 1.0 - clamp(
			abs(screen_u - bank_valley_center)
					/ max(bank_valley_width, 0.001),
			0.0,
			1.0);
	float steps = max(bank_valley_steps, 1.0);
	float stepped_valley = floor(valley * steps + 0.5) / steps;
	float side_span = mix(
			max(bank_valley_center, 0.001),
			max(1.0 - bank_valley_center, 0.001),
			step(bank_valley_center, screen_u));
	float side_distance = clamp(
			abs(screen_u - bank_valley_center) / side_span,
			0.0,
			1.0);
	float stepped_side = floor(
			pow(side_distance, 0.75) * steps + 0.5
	) / steps;
	return (
			stepped_valley * bank_valley_depth
					- stepped_side * bank_side_rise
	) * h_units
			* (1.0 - mode_isolated);
}


float bank_join_top(
		float screen_u,
		float h_units,
		float valley_offset,
		float qy) {
	float contour_id = floor(screen_u * cells * 1.5);
	float contour_random = floor(
			hash(vec2(contour_id + seed * 11.0, 127.3)) * 3.0
	) - 1.0;
	float contour_offset = contour_random * bank_join_variation * h_units;
	float top_v = h_units * (base_frac - bank_join_height)
			+ valley_offset + contour_offset;
	return floor(top_v / qy) * qy;
}


float smoke_cover(
		float cu_c,
		float cv_c,
		float t,
		float h_units,
		float screen_u) {
	float c = 0.0;
	float valley_offset = bank_valley_offset(screen_u, h_units)
			+ scene3_vertical_roll(screen_u, h_units, t);
	for (int i = -1; i <= 1; i++) {
		c = max(c, banner(
				cu_c,
				cv_c,
				floor(cu_c) + float(i),
				t,
				h_units,
				valley_offset));
	}
	float solid = step(
			h_units * base_frac + valley_offset,
			cv_c
	) * (1.0 - mode_isolated);
	float join_enabled = step(0.001, bank_join_height)
			* (1.0 - mode_isolated);
	float joined_shoulder = step(
			bank_join_top(screen_u, h_units, valley_offset, h_units / pixel_grid.y),
			cv_c
	) * join_enabled;
	return max(max(c, solid), joined_shoulder);
}


void fragment() {
	vec2 uvq = floor(UV * pixel_grid) / pixel_grid;
	float t = TIME;
	float qx = cells / pixel_grid.x;
	float qy_f = (cells / aspect) / pixel_grid.y;
	// 整像素流动步进 + 半像素中心采样（根治闪烁的两把锁）
	float flow_t = floor(t * flow_speed * cells / qx) * qx;
	float cu_c = uvq.x * cells + qx * 0.5 + flow_t + pattern_offset;     // 流动列中心
	float cv_c = uvq.y * cells / aspect + qy_f * 0.5;   // 行中心
	float h_units = cells / aspect;

	float cover = smoke_cover(cu_c, cv_c, t, h_units, uvq.x);
	// 月光缘：本像素在雾内、其上 edge_h 处在雾外 = 顶面暴露 → 一线脆亮
	float cover_up = smoke_cover(
			cu_c, cv_c - edge_h, t, h_units, uvq.x);
	float lit = cover * (1.0 - min(cover_up, 1.0));

	// F 体内两档明度横向流纹：不同行相位错开滚动（只染体色·月光缘不受染）
	float irow = floor(cv_c / (row_h * 0.8));
	float iblk = floor(cu_c * 3.0 - t * 1.1 - irow * 2.7);
	float duo = (step(0.5, hash(vec2(iblk, irow + 61.3))) - 0.5) * inner_contrast;
	vec3 body_rgb = fill_color.rgb * (1.0 + duo);

	float a = min(cover, 1.0) * alpha_max * fill_color.a;
	vec3 rgb = mix(body_rgb, lit_color.rgb, clamp(lit, 0.0, 1.0) * lit_strength);

	// water_reflect_underside: a single hard cyan value on the lower edge of
	// isolated cloud masses near the fall. Continuous cloud banks do not gain
	// a false glowing outline.
	float cover_down = smoke_cover(
			cu_c, cv_c + water_reflect_edge_h, t, h_units, uvq.x);
	float lower_edge = cover * (1.0 - min(cover_down, 1.0));
	float reflect_distance = abs(uvq.x - water_reflect_center_x);
	float reflect_axis = 1.0 - smoothstep(
			water_reflect_half_width,
			water_reflect_half_width + 0.05,
			reflect_distance);
	float water_reflect_underside = step(
			0.12,
			lower_edge * reflect_axis * mode_isolated);
	rgb = mix(
			rgb,
			water_reflect_color.rgb,
			water_reflect_underside * water_reflect_strength);
	float facing = scene2_light_field(SCREEN_UV);
	float receiver_light = cover
			* (0.28 + lit * 0.72)
			* facing;
	float receiver_shadow = cover * (1.0 - facing) * (1.0 - lit * 0.65);
	rgb += directional_light_color.rgb
			* receiver_light * directional_light_strength * 0.18;
	rgb = mix(
			rgb,
			rgb * directional_shadow_color.rgb,
			receiver_shadow * directional_shadow_strength);
	vec2 sun_grid = vec2(480.0, 270.0);
	vec2 sun_uv = (floor(SCREEN_UV * sun_grid) + vec2(0.5)) / sun_grid;
	vec2 sun_delta = (sun_uv - local_sun_screen_pos)
			/ max(local_sun_rim_radius, vec2(0.001));
	float sun_proximity = 1.0 - smoothstep(0.35, 1.0, length(sun_delta));
	float rim_breathe = 0.94 + sin(
			TIME * scene3_billow_speed + scene3_billow_phase) * 0.06;
	float local_sun_rim = clamp(
			lit * sun_proximity * local_sun_rim_strength * rim_breathe,
			0.0,
			1.0);
	rgb = mix(rgb, local_sun_rim_color.rgb, local_sun_rim);
	rgb += local_sun_rim_color.rgb * local_sun_rim * 0.08;
	COLOR = vec4(rgb, a);
}
