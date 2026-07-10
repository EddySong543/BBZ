shader_type canvas_item;

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


float hash(vec2 p) {
	p = mod(p, 289.0);   // ⚠入口取模压量级——sid×31 级大数会让 sin 精度劣化·随机失真（碎齿率失控教训）
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


// 单条雾旗的 2 层旗身（共用）：边界全对齐像素格；端头嵌套拖尾；顶层内区碎齿。
// cu_c 传入的是【像素列中心】坐标（半像素偏置·防浮点等号抖动）。
float banner_rows(float cu_c, float cv_c, float sid, float cx, float len, float base_v, float q) {
	float has = step(0.05, len);   // ⚠无旗（len=0）必须整体归零——最小宽度保底曾把空格撑成 4 列幽灵云（单格云病根）
	float c = 0.0;
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float w = max(floor(len * mix(1.0, 0.58, fk) / q) * q, q * 4.0);   // 宽度对齐格·最少 4 列
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
		c = max(c, in_x * in_y * (1.0 - min(1.0, erode_end + notch)));
	}
	return c * has;
}


// 流动雾旗（簇状分布 + 结构保底 + 呼吸 + 量化缓漂/起伏）。
float banner(float cu_c, float cv_c, float id, float t, float h_units) {
	float sid = id + seed * 97.0;
	float cluster_on = step(hash(vec2(floor(id / 3.0) + seed * 13.0, 41.7)), keep);
	// 结构保底：每第 3 格必出一条旗（随流照滚）→ 屏幕中部任何时刻必有云·开局不空
	// （⚠常驻钉死旗方案已否——不随流的云读作"卡住"·2026-07-10 Eddy 报）
	float forced = step(abs(mod(id, 3.0) - 1.0), 0.01) * mode_isolated;
	float on = max(cluster_on * step(hash(vec2(sid, 5.13)), 0.85), forced);
	// 旗长下限抬高（0.35→0.5·拖尾后仍有主体）·长短混排
	float len = cloud_size * (0.5 + 0.95 * hash(vec2(sid, 2.2))) * on;
	// 间隙保证（孤立模式·Eddy 2026-07-10）：旗长封顶 0.78 格 + 落位抖动只用剩余空隙的一半
	// → 相邻旗最小间隙 ≥0.18 格（~50-60px）·雾墙模式不封顶（要互相搭接成整条）
	len = min(len, mix(9.0, 0.78, mode_isolated));
	float q = cells / pixel_grid.x;
	float sway = floor(sin(t * sway_speed + id * 2.17) * 0.02 / q + 0.5) * q;
	float jit = (hash(vec2(sid, 9.7)) - 0.5)
			* mix(0.3, max(1.0 - len - 0.22, 0.0), mode_isolated);
	float cx = id + 0.5 + jit + sway;
	float qy = h_units / pixel_grid.y;
	float bob = floor((1.0 - mode_isolated) * sin(t * 0.4 + id * 1.9) * row_h * 0.6 / qy + 0.5) * qy;
	float base_v = h_units * base_frac + bob;
	// 呼吸只给孤立旗——雾墙内旗互相搭接·各旗呼吸相位不同会在搭接边出"明暗脉动竖缝"（max 并集台阶）
	float breath = 1.0 - breath_amount * mode_isolated * (0.5 + 0.5 * sin(t * breath_speed + id * 2.9));
	return banner_rows(cu_c, cv_c, sid, cx, len, base_v, q) * breath;
}


// 全场覆盖：邻格三旗取并；雾墙模式再并上基线以下连体实身。
float smoke_cover(float cu_c, float cv_c, float t, float h_units) {
	float c = 0.0;
	for (int i = -1; i <= 1; i++) {
		c = max(c, banner(cu_c, cv_c, floor(cu_c) + float(i), t, h_units));
	}
	float solid = step(h_units * base_frac, cv_c) * (1.0 - mode_isolated);
	return max(c, solid);
}


void fragment() {
	vec2 uvq = floor(UV * pixel_grid) / pixel_grid;
	float t = TIME;
	float qx = cells / pixel_grid.x;
	float qy_f = (cells / aspect) / pixel_grid.y;
	// 整像素流动步进 + 半像素中心采样（根治闪烁的两把锁）
	float flow_t = floor(t * flow_speed * cells / qx) * qx;
	float cu_c = uvq.x * cells + qx * 0.5 + flow_t;     // 流动列中心
	float cv_c = uvq.y * cells / aspect + qy_f * 0.5;   // 行中心
	float h_units = cells / aspect;

	float cover = smoke_cover(cu_c, cv_c, t, h_units);
	// 月光缘：本像素在雾内、其上 edge_h 处在雾外 = 顶面暴露 → 一线脆亮
	float cover_up = smoke_cover(cu_c, cv_c - edge_h, t, h_units);
	float lit = cover * (1.0 - min(cover_up, 1.0));

	// F 体内两档明度横向流纹：不同行相位错开滚动（只染体色·月光缘不受染）
	float irow = floor(cv_c / (row_h * 0.8));
	float iblk = floor(cu_c * 3.0 - t * 1.1 - irow * 2.7);
	float duo = (step(0.5, hash(vec2(iblk, irow + 61.3))) - 0.5) * inner_contrast;
	vec3 body_rgb = fill_color.rgb * (1.0 + duo);

	float a = min(cover, 1.0) * alpha_max * fill_color.a;
	vec3 rgb = mix(body_rgb, lit_color.rgb, clamp(lit, 0.0, 1.0) * lit_strength);
	COLOR = vec4(rgb, a);
}
