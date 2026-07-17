shader_type canvas_item;

// ── 波波攒 · 主菜单 / 选人界面 单色对波背景（canvas_env_wave_flow）· v3「对波解剖」─────
//
// 目标平台：Forward+ / Mobile / Compatibility（canvas_item，复杂度低，仅算术，无纹理采样）。
//
// 2026-07-17 与 boot（canvas_boot_wave_clash.gdshader）同步 v3 对波解剖（Eddy：波家族全线同风格）：
//   · 底场＝平坦安静（⛔满屏颗粒：底场在片元内钉到量化档中点 + 能量体死区裁尾 → 零棋盘纹）
//   · 波前三层＝暗缘 + 爆亮芯 + 色鞘（颗粒只在鞘内）——氛围背景用「安静档」增益（无电性碎抖/能量丝）
//   · 红 / 蓝 ramp 与 boot 完全一致；单色由 use_blue 选定（= boot 胜方色）
// 保留本文件既有：单向缓慢流动 / 呼吸 B / 静息区 E / 色彩弧「舒适淡色↔满饱和」（uniform 接口零改动）。
//
// 由 wave_flow_bg.gd 每帧驱动：
//   phase      : 横向流动累积相位（脚本每帧 += delta * drift_speed）
//   wave_time  : 纵向波纹漂浮相位（与横向解耦）
//   use_blue   : 1 = 蓝侧色 / 0 = 红侧色（继承 boot 胜方）
//   drift_dir  : +1 向右流 / -1 向左流（继承 boot 胜方推进方向）
//   aspect     : 视口宽高比（脚本据视口尺寸设置，保证格子为正方）

uniform float aspect = 1.777;
uniform float cells_x = 64.0;                          // 横向像素格数（与 boot 一致）
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

uniform float base_level : hint_range(0.0, 1.0) = 0.30; // 底色亮度档（片元内自动钉到量化档中点）
uniform float wave_amp : hint_range(0.0, 0.6) = 0.18;   // 流动波振幅
uniform float phase = 0.0;                              // 横向流动相位（脚本驱动）
uniform float wave_time = 0.0;                          // 纵向漂浮相位（脚本驱动）
uniform float drift_dir = 1.0;                          // +1 右 / -1 左

uniform int levels : hint_range(8, 96) = 40;
uniform float dither_amt : hint_range(0.0, 2.0) = 1.0;
uniform float use_blue : hint_range(0.0, 1.0) = 1.0;    // 1 = 蓝 / 0 = 红（boot 胜方）

// ── 色彩弧 ·「舒适淡色 ↔ 满饱和」（2026-06-24·方案C·由 wave_flow_bg.gd 驱动）─────
uniform vec3 pale_color : source_color = vec3(0.65, 0.74, 0.82);  // 当前侧舒适淡锚色（脚本设）
uniform float sat : hint_range(0.0, 1.0) = 1.0;          // 0 = 全淡锚色 / 1 = 满饱和 ramp

// ── 降疲劳 · B「平息动效」+ E「静息区」（2026-06-24，由 wave_flow_bg.gd 驱动）─────
uniform float breath = 0.0;                              // 【B】振幅缓慢呼吸（脚本喂 sin 值）
uniform float rest_enable = 0.0;                         // 【E】0 关 / 1 开
uniform vec2  rest_center = vec2(0.5, 0.47);            // 【E】静息区中心（UV·对准三卡区）
uniform vec2  rest_size   = vec2(0.40, 0.33);          // 【E】椭圆半径（UV）
uniform float rest_soft : hint_range(0.02, 1.0) = 0.55; // 【E】边缘羽化
uniform float rest_motion : hint_range(0.0, 1.0) = 0.25;// 【E】区内保留多少波振幅
uniform float rest_smooth : hint_range(0.0, 1.0) = 0.40;// 【E】区内保留多少颗粒/抖动

const int WAVE_COUNT = 4;                               // 同时在屏的波列道数

// ── v3 解剖旋钮（氛围背景=安静档·比 boot 克制）────────────────────
const float K_CORE = 6500.0;         // 波前爆亮芯高斯衰减（半宽 ~0.8 格）
const float K_SHEATH = 90.0;         // 色鞘拖尾衰减（半宽 ~5.6 格）
const float K_RIM = 5000.0;          // 暗缘衰减
const float RIM_AHEAD = 0.018;       // 暗缘在芯前方的距离
const float CORE_GAIN = 2.2;         // 芯亮度增益（安静档·boot=2.4）
const float SHEATH_GAIN = 1.4;       // 鞘亮度增益
const float RIM_DARK = 0.50;         // 暗缘压暗量

// 死区裁尾：指数长尾低于 DEAD 归零（连续无跳变）——没有它微量尾巴把平坦底场推离档中点=棋盘纹复发。
const float DEAD = 0.06;

// Bayer 4x4 有序抖动矩阵（值 0..15，用于档位边界棋盘交错）——与 boot 一致
const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

float dz(float v) {
	return max(v - DEAD, 0.0) / (1.0 - DEAD);
}

// ── 蓝色 ramp（与 wave_clash / boot 完全一致）─────
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

// ── 红色 ramp（与 wave_clash / boot 完全一致）─────
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

// ── 波前三层剖面：x=爆亮芯 y=色鞘(仅波后) z=暗缘(芯前一格)（boot v3 同构）─────
vec3 front_profile(float s) {
	float core = dz(exp(-s * s * K_CORE));
	float sheath = dz(exp(-s * s * K_SHEATH)) * step(s, 0.0);
	float d = s - RIM_AHEAD;
	float rim = dz(exp(-d * d * K_RIM));
	return vec3(core, sheath, rim);
}

// 单向流动的多道波场：WAVE_COUNT 道等间距波前随 phase 缓缓横扫整屏；
// 出/入屏生命周期包络淡入淡出。返回三层剖面（分量取 max）。
vec3 wave_field(float x) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < WAVE_COUNT; i++) {
		float c = fract(phase + float(i) / float(WAVE_COUNT));
		float travel = drift_dir > 0.0 ? c : (1.0 - c);
		float pos = mix(-0.15, 1.15, travel);
		float env = smoothstep(0.0, 0.12, c) * (1.0 - smoothstep(0.82, 1.0, c));
		float s = (x - pos) * drift_dir;
		acc = max(acc, front_profile(s) * env);
	}
	return acc;
}

// 【E】区外 = 1 / 区内 = 0（带羽化）。rest_enable=0 时恒为 1。
float rest_outside(vec2 uv) {
	if (rest_enable < 0.5) return 1.0;
	vec2 d = (uv - rest_center) / max(rest_size, vec2(0.001));
	float r = length(d);
	return smoothstep(1.0 - rest_soft, 1.0, r);
}

// 每格中心算亮度 L (0~1)。outf = rest_outside（区内压振幅 + 压颗粒）。
float energy(vec2 cuv, vec2 ci, float outf) {
	float cell_hash = fract(sin(dot(ci, vec2(12.9898, 78.233))) * 43758.5453);
	// 底场：钉到量化档中点（(k+0.5)/levels）→ 无论脚本喂什么 base_level·平坦底场
	// 恒在档带正中·Bayer ±0.47 档不过界 → 零棋盘纹（v3 纪律）。
	float L_base = (floor(base_level * float(levels)) + 0.5) / float(levels);
	// 纵向振幅调制：仅 sin 波纹起伏（⛔颗粒——颗粒只留鞘内）
	float y_amp = 0.85 + sin(cuv.y * 12.0 + wave_time) * 0.15;
	vec3 w = wave_field(cuv.x);
	float amp = wave_amp * (1.0 + breath);                     // 【B】呼吸
	amp *= mix(rest_motion, 1.0, outf);                        // 【E】区内压振幅
	float grain_scale = mix(rest_smooth, 1.0, outf);           // 【E】区内压颗粒
	float grain = 0.75 + cell_hash * 0.50 * grain_scale;
	float L = L_base + (w.x * CORE_GAIN + w.y * SHEATH_GAIN * grain) * amp * y_amp
			- w.z * RIM_DARK * amp;
	return clamp(max(L, 0.03) * intensity, 0.0, 0.9999);
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(UV * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float outf = rest_outside(cuv);
	float L = energy(cuv, ci, outf);

	// Bayer 抖动后量化（底场已平·抖动只见于波体渐变处；区内同步压抖动）
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
