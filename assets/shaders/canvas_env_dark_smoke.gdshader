shader_type canvas_item;

// =============================================================
// canvas_env_dark_smoke.gdshader v3 — 前/中景像素烟云（参照 ref/ref20.png·Eddy 2026-07-10 二次纠偏）
// 作者: Claude (Game Studios) ｜ 用途: scene1 战斗舞台氛围层
// v3 像素块派（v1 噪声雾/v2 圆瓣拼形均被否）：
//   mode_isolated=1 孤立云：一朵朵=长方形逐层堆砌（底层最宽·逐层收窄·每层横向错位=阶梯边·
//     底部完全平整·明显像素感）·各朵独立缓漂 + 整体缓慢流动
//   mode_isolated=0 前景带：一整条连续循环的阶梯波形烟墙·贴屏幕底边=画框（压底边强化画面中心）·
//     波形上缘按列阶梯量化·无限循环滚动
// 局部条带非全屏；纯矩形拼合 + 轻噪声·循环内零纹理采样。复杂度：低。
// 坐标系：x 单位=格宽（cells 均分 rect 宽）·y 经 aspect 归一到同单位。
// =============================================================

uniform vec4 fill_color : source_color = vec4(0.14, 0.16, 0.21, 1.0);  // 烟体色
uniform vec4 lit_color : source_color = vec4(0.42, 0.5, 0.66, 1.0);    // 受月光顶层色
uniform float lit_strength : hint_range(0.0, 1.0) = 0.55;  // 顶层亮色混入比例（0=纯单色）
uniform float alpha_max : hint_range(0.0, 1.0) = 0.75;
uniform float flow_speed = 0.012;     // 整体流速（格/秒·循环滚动）
uniform float sway_speed = 0.4;       // 孤立云：单朵缓漂相位速度
uniform float mode_isolated : hint_range(0.0, 1.0) = 1.0;  // 1=孤立云 0=前景带
uniform float cells = 7.0;            // x 向格数（孤立云=每格至多一朵）
uniform float keep : hint_range(0.0, 1.0) = 0.6;    // 孤立云：出云比例
uniform float cloud_size : hint_range(0.4, 2.0) = 1.0;
uniform float base_frac : hint_range(0.0, 1.0) = 0.8;   // 孤立云：平底基线（rect 高度比例）
uniform float row_h = 0.055;          // 堆砌层高（格宽单位·两模式共用=像素层厚）
uniform float band_h_frac : hint_range(0.0, 1.0) = 0.45;   // 带：基础高度（rect 高度比例·自底向上）
uniform float band_wave_frac : hint_range(0.0, 0.6) = 0.28; // 带：波峰额外起伏（rect 高度比例）
uniform float band_col = 0.05;        // 带：阶梯列宽（格宽单位·列内同高=像素阶梯）
uniform float frame_lift : hint_range(0.0, 0.6) = 0.18;    // 带：画框提升——越靠屏幕两侧越高·中心最低
uniform float aspect = 19.3;          // rect 宽高比 W/H（按实例配）
uniform vec2 pixel_grid = vec2(900.0, 47.0);   // 粗像素格（rect 尺寸/3px）


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	vec2 uvq = floor(UV * pixel_grid) / pixel_grid;
	float t = TIME;
	float cu = uvq.x * cells + t * flow_speed * cells;   // 流动坐标（单位=格宽）
	float cv = uvq.y * cells / aspect;
	float h_units = cells / aspect;

	// —— 孤立云：长方形逐层堆砌（底平·逐层收窄·每层错位）——
	float cloud_cover = 0.0;
	float cloud_lit = 0.0;
	for (int i = -1; i <= 1; i++) {
		float id = floor(cu) + float(i);
		float on = step(hash(vec2(id, 5.13)), keep);
		float sz = cloud_size * (0.75 + 0.5 * hash(vec2(id, 2.2))) * on;
		float cx = id + 0.5 + (hash(vec2(id, 9.7)) - 0.5) * 0.24
				+ sin(t * sway_speed + id * 2.17) * 0.015;   // 缓漂极小幅=地面烟尘感
		// 平底钉基线（Eddy：与房檐精准重合——底线不加随机抖·下沿略漫过地面线=贴地）
		float base_v = h_units * base_frac;
		float nrows = 1.0 + step(0.35, hash(vec2(id, 11.1)));   // 1~2 层（ref21 地烟·总高远低于膝盖）
		for (int k = 0; k < 2; k++) {
			float fk = float(k);
			float row_on = step(fk, nrows - 1.0);
			// 贴地横条：底层宽扁·顶层短小且大错位（ref21 深紫地烟的碎片感）
			float w = sz * mix(0.85, 0.32, fk) * (0.75 + 0.5 * hash(vec2(id, 20.0 + fk))) * row_on;
			float ox = (hash(vec2(id, 30.0 + fk)) - 0.5) * (0.12 + 0.3 * fk) * sz;
			float in_x = step(abs(cu - (cx + ox)), w * 0.5);
			float y_bot = base_v - row_h * fk;
			float in_y = step(y_bot - row_h, cv) * step(cv, y_bot);
			float c = in_x * in_y;
			cloud_cover = max(cloud_cover, c);
			cloud_lit = max(cloud_lit, c * fk);   // 仅顶层微光
		}
	}

	// —— 前景带：连续循环阶梯波形烟墙（画框·贴底）——
	float colc = (floor(cu / band_col) + 0.5) * band_col;   // 列中心（列内同高=阶梯）
	float wave = sin(colc * 0.85 + t * 0.3) * 0.5
			+ sin(colc * 2.3 - t * 0.22) * 0.3
			+ (hash(vec2(floor(cu / band_col), 7.7)) - 0.5) * 0.5;
	// 画框提升：越靠屏幕两侧越高（uvq.x 是 rect 本地坐标·不随流动滚·框感钉住）
	float lift = pow(abs(uvq.x - 0.5) * 2.0, 2.0) * frame_lift;
	float bh = h_units * (band_h_frac + band_wave_frac * (wave * 0.5 + 0.5) + lift);
	bh = floor(bh / row_h) * row_h;                          // 高度量化到层高=阶梯边
	float band_cover = step(h_units - bh, cv);
	float band_lit = band_cover * step(cv, h_units - bh + row_h);   // 顶层一阶受月光

	// —— 模式混合 + 上色（体内轻噪声防死平）——
	float cover = mix(band_cover, cloud_cover, mode_isolated);
	float lit = mix(band_lit, cloud_lit, mode_isolated);
	float n = hash(vec2(floor(cu / band_col), floor(cv / row_h)));   // 块级噪声（不破坏像素块感）
	float a = cover * alpha_max * (0.92 + 0.08 * n) * fill_color.a;
	vec3 rgb = mix(fill_color.rgb, lit_color.rgb, lit * lit_strength);
	COLOR = vec4(rgb, a);
}
