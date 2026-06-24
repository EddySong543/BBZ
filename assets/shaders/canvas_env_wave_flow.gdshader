shader_type canvas_item;

// ── 波波攒 · 主菜单 / 选人界面 单色对波背景（canvas_env_wave_flow）─────
//
// 目标平台：Forward+ / Mobile / Compatibility（canvas_item，复杂度低，仅算术，无纹理采样）。
//
// 继承 boot_screen 的对波启动过场（wave_clash.gdshader）的"质感"，但简化为安静的氛围背景：
//   · 非对称浪头波形（陡前缘 + 长拖尾）——与 boot 同一套 wave_head
//   · 2D 格点 hash 颗粒 + Bayer 4x4 抖动 + 档位量化——与 boot 同一套复古像素渐变
//   · 红 / 蓝两套 color ramp——色值与 boot 完全一致；单色，由 use_blue 选定（= boot 胜方色）
// 去掉 boot 的：对撞脉冲 / 中央白柱 / 连击闪 / 崩溃爆发 / 涟漪。
// 运动：单向缓慢横向平移（drift_dir 决定方向），竖直波列朝一个方向缓缓流过整屏。
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

uniform float base_level : hint_range(0.0, 1.0) = 0.30; // 底色亮度档（菜单背景压暗，让角色/UI 突出）
uniform float wave_amp : hint_range(0.0, 0.6) = 0.18;   // 流动波振幅
uniform float phase = 0.0;                              // 横向流动相位（脚本驱动）
uniform float wave_time = 0.0;                          // 纵向漂浮相位（脚本驱动）
uniform float drift_dir = 1.0;                          // +1 右 / -1 左

uniform int levels : hint_range(8, 96) = 40;
uniform float dither_amt : hint_range(0.0, 2.0) = 1.0;
uniform float use_blue : hint_range(0.0, 1.0) = 1.0;    // 1 = 蓝 / 0 = 红（boot 胜方）

// ── 降疲劳 · B「平息动效」+ E「静息区」（2026-06-24，由 wave_flow_bg.gd 驱动）─────
// 默认全关（breath=0 / rest_enable=0）→ 与并入前完全一致；驱动脚本按 @export 旋钮开启。
uniform float breath = 0.0;                              // 【B】振幅缓慢呼吸（脚本喂 sin 值，动而不躁）
uniform float rest_enable = 0.0;                         // 【E】0 关 / 1 开
uniform vec2  rest_center = vec2(0.5, 0.47);            // 【E】静息区中心（UV·对准三卡区）
uniform vec2  rest_size   = vec2(0.40, 0.33);          // 【E】椭圆半径（UV）
uniform float rest_soft : hint_range(0.02, 1.0) = 0.55; // 【E】边缘羽化（越大越柔·越不像盖板）
uniform float rest_motion : hint_range(0.0, 1.0) = 0.25;// 【E】区内保留多少波振幅（0=静止·1=满）
uniform float rest_smooth : hint_range(0.0, 1.0) = 0.40;// 【E】区内保留多少颗粒/抖动（0=玻璃滑·1=满）

const int WAVE_COUNT = 4;                               // 同时在屏的波列道数

// Bayer 4x4 有序抖动矩阵（值 0..15，用于档位边界棋盘交错）——与 boot 一致
const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

// ── 蓝色 ramp（与 wave_clash.gdshader 完全一致）─────
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

// ── 红色 ramp（与 wave_clash.gdshader 完全一致）─────
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

// ── 非对称浪头（与 boot 一致）：s = 沿传播方向的有符号距离 ─────
// s>0 在波前（即将到达）→ 陡前缘；s<0 在波尾（已掠过）→ 长拖尾
float wave_head(float s) {
	float K_FRONT = 520.0;
	float K_BACK  = 70.0;
	return s > 0.0 ? exp(-s * s * K_FRONT) : exp(-s * s * K_BACK);
}

// 单向流动的多道波场：WAVE_COUNT 道等间距浪头，随 phase 缓缓横扫整屏；
// 每道在出 / 入屏处用生命周期包络淡入淡出，无突变。返回该列波强度 0~1。
float wave_field(float x) {
	float acc = 0.0;
	for (int i = 0; i < WAVE_COUNT; i++) {
		float c = fract(phase + float(i) / float(WAVE_COUNT));
		// drift_dir 决定行进方向：+1 时波头位置随 c 增大右移；-1 时左移
		float travel = drift_dir > 0.0 ? c : (1.0 - c);
		float pos = mix(-0.15, 1.15, travel);          // 从屏外一侧推进到屏外另一侧
		float env = smoothstep(0.0, 0.12, c) * (1.0 - smoothstep(0.82, 1.0, c));
		float s = (x - pos) * drift_dir;
		acc = max(acc, wave_head(s) * env);
	}
	return acc;
}

// 【E】区外 = 1 / 区内 = 0（带羽化）。rest_enable=0 时恒为 1（= 并入前，无影响）。
float rest_outside(vec2 uv) {
	if (rest_enable < 0.5) return 1.0;
	vec2 d = (uv - rest_center) / max(rest_size, vec2(0.001));
	float r = length(d);                        // 1.0 在椭圆边界
	return smoothstep(1.0 - rest_soft, 1.0, r); // 内 0 → 外 1
}

// 每格中心算亮度 L (0~1)。outf = rest_outside（区内压振幅 + 压颗粒）。
float energy(vec2 cuv, vec2 ci, float outf) {
	// 2D 格点 hash 颗粒（与 boot 一致：随机点而非水平长条）
	float cell_hash = fract(sin(dot(ci, vec2(12.9898, 78.233))) * 43758.5453);
	float grain = cell_hash - 0.5;
	float grain_scale = mix(rest_smooth, 1.0, outf);            // 【E】区内压颗粒
	float L_base = base_level + grain * 0.05 * grain_scale;
	// 纵向振幅调制：sin 波纹起伏 + 格点颗粒
	float y_amp = 0.80 + sin(cuv.y * 12.0 + wave_time) * 0.18 + grain * 0.30 * grain_scale;
	float w = wave_field(cuv.x);
	float amp = wave_amp * (1.0 + breath);                     // 【B】呼吸
	amp *= mix(rest_motion, 1.0, outf);                        // 【E】区内压振幅
	float L = L_base + w * amp * y_amp;
	return clamp(L * intensity, 0.0, 0.9999);
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(UV * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float outf = rest_outside(cuv);
	float L = energy(cuv, ci, outf);

	// Bayer 抖动后量化：档位边界棋盘交错（复古像素渐变）——与 boot 一致
	// （区内同步压抖动幅度，避免静息区里还有棋盘颗粒）
	int bx = int(mod(ci.x, 4.0));
	int by = int(mod(ci.y, 4.0));
	float dith = (BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5;
	float dith_scale = mix(rest_smooth, 1.0, outf);
	L = clamp(L + dith * dither_amt * dith_scale / float(levels), 0.0, 0.9999);
	L = floor(L * float(levels)) / float(levels);

	vec3 col = use_blue > 0.5 ? blue_color_at(L) : red_color_at(L);
	COLOR = vec4(col, 1.0);
}
