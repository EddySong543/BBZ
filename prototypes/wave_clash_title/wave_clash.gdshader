shader_type canvas_item;

// ── 波波攒 · 对波加载界面（多档颜色渐变 + 持续涌入小波 版）─────
//
// 核心机制（认知纠偏后的正确路线）：
//   1) 大方格 64 列，每格中心采样、整格纯色，无渐变无噪点
//   2) 亮度量化 levels=40 档（不是 5 档！）→ 蓝/红各 40 个由暗到亮的层次
//   3) 颜色 ramp 在 5 个关键色之间用 mix 插值；L 量化后查 ramp → 40 种蓝 + 40 种红
//   4) 相邻格 cuv 差 1/64 → energy 差 0.01-0.03 → 跨多档 → 相邻格自然显色差
//      → 不需要任何边框/暗缝/描边来"勾勒"格子（前几版都弃）
//
// 时间轴 uniforms（脚本驱动）：
//   pulse_l_x / pulse_r_x : 大波位置（推进期 0→0.5 / 1→0.5）
//   pulse_amp             : 大波振幅（推进期 1，撞击后衰减到 0）
//   center_amp            : 中央白柱（撞击后 tween 起，僵持期 0.9-1.1 微脉动）
//   wave_amp              : 持续涌入小波振幅（撞击后 0→0.22 维持）
//   wave_time             : 小波相位（脚本每帧持续推进 → 波向中心传播）
//   clash_pos             : 中央边界（僵持期 _struggle 小幅游走；sweep 期 tween 到 0/1）

uniform float clash_pos : hint_range(0.0, 1.0) = 0.5;
uniform float aspect = 1.777;
uniform float cells_x = 64.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;   // 撞击短促闪用；僵持期固定 1.0 不再全屏脉动

uniform float pulse_l_x : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_r_x : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_amp : hint_range(0.0, 2.0) = 1.0;
uniform float center_amp : hint_range(0.0, 1.5) = 0.0;

uniform float wave_amp : hint_range(0.0, 0.6) = 0.0;
uniform float wave_time = 0.0;
uniform float wave_freq = 60.0;                          // 相邻格相位差 ~0.94 弧度 → 跨多档色差

uniform int levels : hint_range(8, 96) = 40;             // 颜色档位数（关键旋钮）

// ── 蓝色 ramp：5 个关键色之间 mix（输入量化后的 L 0~1）─────
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

// 每格中心算亮度 L (0~1)
float energy(vec2 cuv) {
	// 1) 底色：盖过越多越亮（flood）→ 自动实现"盖过逐渐高亮"
	float flood = abs(clash_pos - 0.5) * 2.0;
	float L_base = mix(0.35, 0.72, flood);

	// 2) 大波（推进期主角）：高斯衰减 30 让波宽 ~10 格 → 多格明暗渐变
	float dl = cuv.x - pulse_l_x;
	float dr = pulse_r_x - cuv.x;
	float L_pulse_l = exp(-dl * dl * 30.0) * pulse_amp;
	float L_pulse_r = exp(-dr * dr * 30.0) * pulse_amp;

	// 3) 中央白柱（僵持期主角）
	float L_center = exp(-abs(cuv.x - clash_pos) * 14.0) * center_amp;

	// 4) 持续涌入的小波（僵持期 wave_time 持续推进 → 永不静止 + 让相邻格 L 跨档显色差）
	//    关键：① wave 加在 base 上（不是 max）→ base 区每格都有 L 波动 → 颜色丰富
	//          ② 相位加 cuv.y * 6.0 纵向偏移 → 相邻列同行也有 L 差 → 显 64×36 方格颗粒
	//          ③ y_phase 系数 6 让波峰倾斜 ~0.4° 几乎不可见，视觉仍是"竖直波峰水平推进"
	float side = step(cuv.x - clash_pos, 0.0);
	float y_phase = cuv.y * 6.0;
	float ph_l = sin(cuv.x * wave_freq - wave_time + y_phase) * 0.5 + 0.5;
	float ph_r = sin((1.0 - cuv.x) * wave_freq - wave_time + y_phase) * 0.5 + 0.5;
	float dist_l = max(clash_pos - cuv.x, 0.0);
	float dist_r = max(cuv.x - clash_pos, 0.0);
	float L_wave_l = ph_l * wave_amp * smoothstep(0.0, 0.25, dist_l) * side;
	float L_wave_r = ph_r * wave_amp * smoothstep(0.0, 0.25, dist_r) * (1.0 - side);

	// base + wave 让两侧版图持续波动；pulse / center 通过 max 在关键位置主导
	float L_base_modulated = L_base + L_wave_l + L_wave_r;
	float L = max(L_base_modulated, max(max(L_pulse_l, L_pulse_r), L_center));
	return clamp(L * intensity, 0.0, 0.9999);
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(UV * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float L = energy(cuv);
	// 多档量化：L 落到 0/levels, 1/levels, ..., (levels-1)/levels 之一
	L = floor(L * float(levels)) / float(levels);

	float side = step(cuv.x - clash_pos, 0.0);
	vec3 col = mix(red_color_at(L), blue_color_at(L), side);

	COLOR = vec4(col, 1.0);
}
