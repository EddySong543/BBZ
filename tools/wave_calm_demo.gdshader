shader_type canvas_item;

// ── 波波攒 ·【一次性 DEMO】菜单波「B 平息动效 + E 静息区」对比 ───────────────
//
// 作者：Claude（应 Eddy 要求 · 2026-06-24）。
// 用途：F6 实时试 B / E 两条「降疲劳」杠杆，定好参数后再决定是否并回 canvas_env_wave_flow。
// 目标平台：Forward+ / Mobile / Compatibility（canvas_item · 仅算术 · 无纹理采样）。
//
// 基线保真：rest_enable=0 且 breath=0、wave_amp/drift 用生产默认时，
//           本 shader 输出与 assets/shaders/canvas_env_wave_flow.gdshader 完全一致 → 可直接左右对比。
//
// 相对生产新增的两块（其余 ramp / 波形 / 抖动逐字复制生产）：
//   · breath   ：【B】振幅缓慢呼吸（脚本每帧喂 sin 值）—— 动而不躁，眼睛不被持续 churn 牵着走。
//   · rest_*   ：【E】屏中央一块软椭圆「静息区」—— 区内压波峰振幅 + 压颗粒/抖动，区外满血。
//                给眼睛一块低活动区歇脚，又不破「全屏波流」。
//   ⚠ E 默认椭圆 blob（非水平横带）：横带极易读成「海平线 / 海面化」，是被否过的方向。

// ── 与生产一致的基础旋钮 ─────
uniform float aspect = 1.777;
uniform float cells_x = 64.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.08;   // 对齐生产菜单材质
uniform float base_level : hint_range(0.0, 1.0) = 0.46;  // 对齐生产菜单材质
uniform float wave_amp : hint_range(0.0, 0.6) = 0.18;
uniform float phase = 0.0;
uniform float wave_time = 0.0;
uniform float drift_dir = 1.0;
uniform int levels : hint_range(8, 96) = 40;
uniform float dither_amt : hint_range(0.0, 2.0) = 1.0;
uniform float use_blue : hint_range(0.0, 1.0) = 1.0;

// ── 色彩弧 · 「舒适淡色 ↔ 满饱和对撞」（脚本驱动）─────
uniform vec3 pale_color : source_color = vec3(0.76, 0.83, 0.85);  // 当前侧舒适淡锚色（脚本按 调色板+胜方 设）
uniform float sat : hint_range(0.0, 1.0) = 1.0;          // 0 = 全淡锚色 / 1 = 满饱和 ramp（点击→点燃升 sat）

// ── 【B】呼吸：脚本驱动 breath = sin(t·spd)·amt，乘进振幅；范围约 -amt..+amt ─────
uniform float breath = 0.0;

// ── 【E】静息区（软椭圆 · 区内平息）─────
uniform float rest_enable = 0.0;                          // 0 关 / 1 开
uniform vec2  rest_center = vec2(0.5, 0.47);             // 静息区中心（UV）—— 对准三卡区
uniform vec2  rest_size   = vec2(0.40, 0.33);           // 椭圆半径（UV）
uniform float rest_soft : hint_range(0.02, 1.0) = 0.55;  // 边缘羽化（越大越柔，越不像盖板）
uniform float rest_motion : hint_range(0.0, 1.0) = 0.25; // 区内保留多少波振幅（0=静止 · 1=满）
uniform float rest_smooth : hint_range(0.0, 1.0) = 0.40; // 区内保留多少颗粒/抖动（0=玻璃滑 · 1=满）

const int WAVE_COUNT = 4;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

// ── 蓝色 ramp（与生产一致）─────
vec3 blue_color_at(float L) {
	vec3 c0 = vec3(0.04, 0.07, 0.18);
	vec3 c1 = vec3(0.08, 0.20, 0.42);
	vec3 c2 = vec3(0.16, 0.36, 0.74);
	vec3 c3 = vec3(0.30, 0.60, 1.00);
	vec3 c4 = vec3(0.70, 0.88, 1.00);
	vec3 cW = vec3(1.00, 1.00, 1.00);
	if (L < 0.20) return mix(c0, c1, L / 0.20);
	if (L < 0.40) return mix(c1, c2, (L - 0.20) / 0.20);
	if (L < 0.60) return mix(c2, c3, (L - 0.40) / 0.20);
	if (L < 0.80) return mix(c3, c4, (L - 0.60) / 0.20);
	return mix(c4, cW, min((L - 0.80) / 0.20, 1.0));
}

// ── 红色 ramp（与生产一致）─────
vec3 red_color_at(float L) {
	vec3 c0 = vec3(0.12, 0.04, 0.03);
	vec3 c1 = vec3(0.32, 0.10, 0.06);
	vec3 c2 = vec3(0.62, 0.18, 0.12);
	vec3 c3 = vec3(0.95, 0.32, 0.22);
	vec3 c4 = vec3(1.00, 0.65, 0.45);
	vec3 cW = vec3(1.00, 1.00, 1.00);
	if (L < 0.20) return mix(c0, c1, L / 0.20);
	if (L < 0.40) return mix(c1, c2, (L - 0.20) / 0.20);
	if (L < 0.60) return mix(c2, c3, (L - 0.40) / 0.20);
	if (L < 0.80) return mix(c3, c4, (L - 0.60) / 0.20);
	return mix(c4, cW, min((L - 0.80) / 0.20, 1.0));
}

// ── 非对称浪头（与生产一致）─────
float wave_head(float s) {
	float K_FRONT = 520.0;
	float K_BACK  = 70.0;
	return s > 0.0 ? exp(-s * s * K_FRONT) : exp(-s * s * K_BACK);
}

// 单向流动的多道波场（与生产一致）。
float wave_field(float x) {
	float acc = 0.0;
	for (int i = 0; i < WAVE_COUNT; i++) {
		float c = fract(phase + float(i) / float(WAVE_COUNT));
		float travel = drift_dir > 0.0 ? c : (1.0 - c);
		float pos = mix(-0.15, 1.15, travel);
		float env = smoothstep(0.0, 0.12, c) * (1.0 - smoothstep(0.82, 1.0, c));
		float s = (x - pos) * drift_dir;
		acc = max(acc, wave_head(s) * env);
	}
	return acc;
}

// 【E】区外 = 1 / 区内 = 0（带羽化）。rest_enable=0 时恒为 1（= 生产，无影响）。
float rest_outside(vec2 uv) {
	if (rest_enable < 0.5) return 1.0;
	vec2 d = (uv - rest_center) / max(rest_size, vec2(0.001));
	float r = length(d);                       // 1.0 在椭圆边界
	return smoothstep(1.0 - rest_soft, 1.0, r);// 内 0 → 外 1
}

// 每格中心算亮度 L (0~1)。outf = rest_outside（区内压振幅 + 压颗粒）。
float energy(vec2 cuv, vec2 ci, float outf) {
	float cell_hash = fract(sin(dot(ci, vec2(12.9898, 78.233))) * 43758.5453);
	float grain = cell_hash - 0.5;
	float grain_scale = mix(rest_smooth, 1.0, outf);          // 区内压颗粒
	float L_base = base_level + grain * 0.05 * grain_scale;
	float y_amp = 0.80 + sin(cuv.y * 12.0 + wave_time) * 0.18 + grain * 0.30 * grain_scale;
	float w = wave_field(cuv.x);
	float amp = wave_amp * (1.0 + breath);                    // 【B】呼吸
	amp *= mix(rest_motion, 1.0, outf);                       // 【E】区内压振幅
	float L = L_base + w * amp * y_amp;
	return clamp(L * intensity, 0.0, 0.9999);
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(UV * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float outf = rest_outside(cuv);
	float L = energy(cuv, ci, outf);

	// Bayer 抖动后量化（区内同步压抖动幅度，避免静息区里还有棋盘颗粒）。
	int bx = int(mod(ci.x, 4.0));
	int by = int(mod(ci.y, 4.0));
	float dith = (BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5;
	float dith_scale = mix(rest_smooth, 1.0, outf);
	L = clamp(L + dith * dither_amt * dith_scale / float(levels), 0.0, 0.9999);
	L = floor(L * float(levels)) / float(levels);

	vec3 col_full = use_blue > 0.5 ? blue_color_at(L) : red_color_at(L);
	// 淡色场：淡锚色 × 随波亮度的轻微起伏（封顶 0.98 避免纯白浪尖）——保留波形但安静。
	vec3 col_pale = clamp(pale_color * (0.80 + 0.32 * L), vec3(0.0), vec3(0.98));
	vec3 col = mix(col_pale, col_full, sat);             // 色彩弧：淡 ↔ 满
	COLOR = vec4(col, 1.0);
}
