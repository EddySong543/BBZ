shader_type canvas_item;

// =============================================================
// canvas_ui_ink_clouds.gdshader v2 — 像素墨云旗（2026-07-13 重做）
// 作者: Claude (Game Studios) ｜ 用途: 道具图鉴宣纸衬底上下环绕的淡墨像素云
//   （衬底之上、卷轴之下·两条横带 quad·仅主菜单直开时挂·战斗内嵌不挂）。
// v1 平滑 fbm 版被否（Eddy：近隐形+读作卡住+非像素）→ v2 参考战斗场景
// canvas_env_dark_smoke v5 的稳定性骨架（烟云六连坑加固），形态做变体；
// v2.1（Eddy：孤立云朵慢+卡卡的）→ 连绵云带：云长放开封顶相邻搭接成整条起伏带·
//   密度拉满·流速提至≈30px/s（步进变每 0.1s 一格=持续流动感）·呼吸改全带同相
//   （⚠异相呼吸在搭接缝出明暗脉动竖缝·烟云雾墙同款教训）。
//   · 三排镜头形墨云：中排浓墨核·上下排淡墨裙边（搭接后=起伏带的毛边）
//   · 整像素流动步进 + 半像素中心采样（防闪烁两把锁·照搬）
//   · 嵌套端头拖尾（外块必先消·永不留孤块·照搬·搭接处自然融合）
//   · 上下带反向漂 + 异 seed（层间不相关·由 GDScript 配）
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 两条 1920×150 带 ×
//   邻域 3 旗 × 3 排 step 判定 → 低。零纹理采样。无动态分支（全 step/mix）。
// =============================================================

group_uniforms ink;
uniform vec4 ink_color : source_color = vec4(0.42, 0.36, 0.27, 1.0); // 墨色（暖灰褐·INK_DIM 家族·⛔冷蓝）
uniform float alpha_core : hint_range(0.0, 0.6) = 0.26;   // 中排浓墨核不透明度（连绵带覆盖大·比孤立版压一档）
uniform float alpha_skirt : hint_range(0.0, 0.6) = 0.15;  // 上下排淡墨裙边不透明度
group_uniforms;

group_uniforms motion;
uniform float flow_speed = 0.03;      // 流速（格/秒·可负=反向·v2.2 起=整层连续滑移非步进·0.03≈7px/s 极缓丝滑）
uniform float sway_speed = 0.15;      // 单云缓漂相位速度（量化步进·搭接带内=内部起伏）
uniform float breath_amount : hint_range(0.0, 0.5) = 0.12;  // 全带同相呼吸幅度（⚠异相会在搭接缝出竖缝）
uniform float breath_speed = 0.35;    // 呼吸速度
group_uniforms;

group_uniforms shape;
uniform float cells = 8.0;            // x 向格数（一格≈一朵云的地盘）
uniform float keep : hint_range(0.0, 1.0) = 1.0;          // 云保留率（1=连绵满带·调低出豁口）
uniform float cloud_size : hint_range(0.3, 2.0) = 1.0;    // 云长基数（格单位）
uniform float center_frac : hint_range(0.0, 1.0) = 0.4;   // 云带垂直中心（带高比例·上下带各配）
uniform float row_h = 0.05;           // 排高（格宽单位·云=3 排）
uniform float seed = 0.0;             // 层种子（⚠上下带必须互异——否则分布相关一起空档）
uniform float aspect = 12.8;          // 带宽高比 W/H（1920/150）
uniform vec2 pixel_grid = vec2(640.0, 50.0);   // 粗像素格（带尺寸/3px）
group_uniforms;


float hash(vec2 p) {
	p = mod(p, 289.0);   // ⚠入口取模压量级——大数进 sin 精度劣化随机失真（烟云教训）
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


// 单朵云的 3 排旗身：中排(k0)长·上排(k1)短右错·下排(k2)短左错；端头嵌套拖尾。
// cu_c/cv_c 为【像素列/行中心】坐标（半像素偏置·防浮点等号抖动）。
// 返回加权覆盖：中排=1.0·裙边排=skirt_w（调用方以 alpha_core 为基乘算）。
float cloud_rows(float cu_c, float cv_c, float sid, float cx, float len, float base_v, float q, float skirt_w) {
	float has = step(0.05, len);   // ⚠无云（len=0）整体归零——最小宽度保底曾撑出幽灵云（单格云病根）
	float acc = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float on_side = step(0.5, fk);                          // 0=中排 1=裙边排
		float dy = (fk - 1.5) * 2.0 * on_side;                  // k1→-1（上） k2→+1（下）
		float wscale = 1.0 - on_side * (0.45 - 0.07 * step(1.5, fk));  // 排宽 1.0/0.55/0.62
		float xs = on_side * mix(0.07, -0.06, step(1.5, fk)) * len;    // 裙边左右错位
		float wgt = mix(1.0, skirt_w, on_side);
		float w = max(floor(len * wscale / q) * q, q * 4.0);    // 宽度对齐格·最少 4 列
		float x0 = floor((cx + xs - w * 0.5) / q) * q;
		float in_x = step(x0, cu_c) * step(cu_c, x0 + w);
		float yc = base_v + dy * row_h;
		float in_y = step(yc - row_h * 0.5, cv_c) * step(cv_c, yc + row_h * 0.5);
		// 嵌套端头拖尾：距端 0/1 子块同一随机数分档阈值（0.75/0.35）→ 外块必先掉·永不留孤块
		float sub_id = floor((cu_c - x0) / 0.07);
		float n_sub = max(floor(w / 0.07), 1.0);
		float edge_d = min(sub_id, n_sub - 1.0 - sub_id);
		float side = step(n_sub - 1.0 - sub_id, sub_id);
		float he = hash(vec2(sid * 31.0 + side * 999.0, 13.7 + fk));
		float erode = step(edge_d, 1.0) * step(he, mix(0.75, 0.35, edge_d));
		acc = max(acc, in_x * in_y * wgt * (1.0 - erode));
	}
	return acc * has;
}


// 单朵流动墨云（连绵模式：长云搭接 + 量化缓漂/浮沉·呼吸移到 fragment 全带同相）。
float cloud(float cu_c, float cv_c, float id, float t, float h_units, float q, float qy, float skirt_w) {
	float sid = id + seed * 97.0;
	float on = step(hash(vec2(sid, 5.13)), keep);   // keep=1 → 满带连绵
	// 云长 0.9-1.6 格 → 相邻云必搭接成整条起伏带（孤立版封顶 0.78 已废）
	float len = cloud_size * (0.9 + 0.7 * hash(vec2(sid, 2.2))) * on;
	len = min(len, 1.6);   // ⚠邻域采样只查 ±1 格——len 超 1.8 会截断出直边
	float sway = floor(sin(t * sway_speed + id * 2.17) * 0.03 / q + 0.5) * q;      // 量化缓漂
	float bob = floor(sin(t * 0.3 + id * 1.9) * row_h * 0.5 / qy + 0.5) * qy;      // 量化浮沉
	float jit = (hash(vec2(sid, 9.7)) - 0.5) * 0.15;
	float cx = id + 0.5 + jit + sway;
	float base_v = h_units * center_frac + bob;
	return cloud_rows(cu_c, cv_c, sid, cx, len, base_v, q, skirt_w);
}


void fragment() {
	float t = TIME;
	float q = cells / pixel_grid.x;
	float h_units = cells / aspect;
	float qy = h_units / pixel_grid.y;
	// v2.2 平滑滑移（Eddy：整像素步进流动读作一帧一帧卡）：平移量加在量化【之前】——
	// 像素块跟随整层连续滑动（视差卷轴层式·块内像素感保留·运动丝滑）。
	// 与烟云"整像素步进"教训不冲突：闪烁源=图案相对屏幕格重算·整层刚性平移无重算；
	// 半像素中心采样仍保留（sway/bob 等格内边界比较的防抖锁）。
	vec2 uv_flow = UV + vec2(t * flow_speed / cells, 0.0);
	vec2 uvq = floor(uv_flow * pixel_grid) / pixel_grid;
	float cu_c = uvq.x * cells + q * 0.5;
	float cv_c = uvq.y * h_units + qy * 0.5;
	float skirt_w = alpha_skirt / max(alpha_core, 0.001);

	float cover = 0.0;
	for (int i = -1; i <= 1; i++) {
		cover = max(cover, cloud(cu_c, cv_c, floor(cu_c) + float(i), t, h_units, q, qy, skirt_w));
	}
	// 呼吸：全带同相（连绵带禁单云异相——搭接缝会出明暗脉动竖缝·烟云雾墙教训）
	float breath = 1.0 - breath_amount * (0.5 + 0.5 * sin(t * breath_speed));
	COLOR = vec4(ink_color.rgb, alpha_core * clamp(cover, 0.0, 1.0) * breath) * COLOR;  // 乘 COLOR=跟随 modulate（节点须白）
}
