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
	float row_idx = floor(cuv.y * 36.0);
	float row_hash = fract(sin(row_idx * 12.9898 + 4.2) * 43758.5453);

	// 1) 底色：盖过越多越亮（flood）+ 微 hash 扰动（全屏每行 ±0.025 → 跨 1 档颗粒）
	//    方格颗粒"全屏底座"：与 wave 解耦，单道波之外的列也保留颗粒
	float flood = abs(clash_pos - 0.5) * 2.0;
	float L_base = mix(0.35, 0.72, flood) + (row_hash - 0.5) * 0.05;

	// 2) 大波（推进期主角）：高斯衰减 30 让波宽 ~10 格 → 多格明暗渐变
	float dl = cuv.x - pulse_l_x;
	float dr = pulse_r_x - cuv.x;
	float L_pulse_l = exp(-dl * dl * 30.0) * pulse_amp;
	float L_pulse_r = exp(-dr * dr * 30.0) * pulse_amp;

	// 3) 中央白柱（僵持期主角）。衰减 8.1 让"对峙发光带"宽 ~7-8 格
	float L_center = exp(-abs(cuv.x - clash_pos) * 8.1) * center_amp;

	// 4) 持续涌入小波（双 cycle 重叠触发 + 左右错相位）
	//    每侧 2 个相位差 0.5 的 cycle，一道接近中央被 envelope 压扁时另一道已从边缘出发
	//    → 过渡期短暂两道并存，平稳期一道主导，max() 合并避免重合爆亮
	//    红侧整体偏移 0.25 周期（~0.83s @WAVE_SPEED=1.5）让左右节奏不同步
	//    单波包高斯衰减 220 ≈ 4 格宽；波相位严格只依赖 cuv.x 和 wave_time（同列同相不变）
	//    y_amp 振幅纵向调制：sin 漂浮 + hash 扰动 0.45（窗帘不刺眼）
	float side = step(cuv.x - clash_pos, 0.0);
	float t_phase = wave_time * 0.3;
	// 蓝侧：A 主、B 半周期错开
	float posA_l = fract(t_phase) * 0.55;
	float posB_l = fract(t_phase + 0.5) * 0.55;
	float dA_l = cuv.x - posA_l;
	float dB_l = cuv.x - posB_l;
	float ph_l = max(exp(-dA_l * dA_l * 220.0), exp(-dB_l * dB_l * 220.0));
	// 红侧：整体偏移 0.25 周期，与蓝侧错开不同步
	float posA_r = 1.0 - fract(t_phase + 0.25) * 0.55;
	float posB_r = 1.0 - fract(t_phase + 0.75) * 0.55;
	float dA_r = cuv.x - posA_r;
	float dB_r = cuv.x - posB_r;
	float ph_r = max(exp(-dA_r * dA_r * 220.0), exp(-dB_r * dB_r * 220.0));
	float y_amp = 0.75 + sin(cuv.y * 15.0 + wave_time * 0.3) * 0.15 + (row_hash - 0.5) * 0.45;
	float dist_l = max(clash_pos - cuv.x, 0.0);
	float dist_r = max(cuv.x - clash_pos, 0.0);
	float L_wave_l = ph_l * wave_amp * y_amp * smoothstep(0.0, 0.25, dist_l) * side;
	float L_wave_r = ph_r * wave_amp * y_amp * smoothstep(0.0, 0.25, dist_r) * (1.0 - side);

	// base + wave 让单道波涌过；pulse / center 通过 max 在关键位置主导
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
