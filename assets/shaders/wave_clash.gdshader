shader_type canvas_item;

// ── 波波攒 · 对波启动过场（boot_screen）着色器 · 风格化 v2b ─────
//
// 从原型 prototypes/wave_clash_title/ 提升为生产资源（2026-05-29）。完整机制与迭代血泪见原型 README。
// 核心：
//   1) 非对称浪头波形：陡前缘 + 长拖尾 → 波"有形"而非亮斑
//   2) 生命周期振幅包络：波从屏幕外淡入、推进到中央侧淡出 → 无"冒出来"
//   3) 2D 格点 hash 颗粒 + Bayer 4x4 dithering → 复古像素渐变（非数据条纹图）
//   4) 连击盖过：hit_flash 撞击局部闪 + burst 全屏光爆发 + shake 受击抖动
//
// 时间轴 uniforms 由 boot_screen.gd 每帧驱动：
//   pulse_l_x / pulse_r_x : 大波位置（推进期 0→0.5 / 1→0.5）
//   pulse_amp             : 大波振幅（推进期 1，撞击后衰减 0）
//   center_amp            : 中央白柱（撞击后起，僵持期微脉动）
//   wave_amp              : 持续涌入小波振幅
//   phase_l / phase_r     : 蓝/红侧小波累积相位（脚本每帧累加，盖过期胜方加速）
//   wave_time             : 仅用于波纹纵向漂浮（与推进相位解耦）
//   hit_flash             : 连击撞击瞬间的中央局部闪（每击 0→1→0）
//   burst                 : 最终崩溃全屏光爆发 0→1.3（以中央为心向外散发、自然衰落）
//   shake                 : 受击屏幕抖动（UV 偏移；连击轻微、崩溃强，脚本驱动衰减）

uniform float clash_pos : hint_range(0.0, 1.0) = 0.5;
uniform float aspect = 1.777;
uniform float cells_x = 64.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

uniform float pulse_l_x : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_r_x : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_amp : hint_range(0.0, 2.0) = 1.0;
uniform float center_amp : hint_range(0.0, 1.5) = 0.0;

uniform float wave_amp : hint_range(0.0, 0.6) = 0.0;
uniform float phase_l = 0.0;
uniform float phase_r = 0.25;
uniform float wave_time = 0.0;

uniform int levels : hint_range(8, 96) = 40;
uniform float dither_amt : hint_range(0.0, 2.0) = 1.0;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.5) = 0.0;
uniform float ripple : hint_range(0.0, 1.0) = 0.0;  // 初撞涟漪：两道竖直亮带自 clash_pos 向左右荡开
uniform vec2 shake = vec2(0.0);

// 像素台阶圆角遮罩（ModeCard 卡面用·默认 0=关，boot 全屏不受影响 2026-06-12）。
// ⚠ Godot clip_children 不执行父节点自定义 shader → 圆角必须由本层自切。
uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;  // 半径(高度UV比例)
uniform float corner_grid : hint_range(12.0, 200.0) = 88.0; // 台阶量化格数(与框 shader 对齐)

// Bayer 4x4 有序抖动矩阵（值 0..15，用于档位边界棋盘交错）
const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

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

// ── 非对称浪头：s = 沿传播方向的有符号距离 ─────
// s>0 在波前（中央侧，即将到达）→ 陡前缘；s<0 在波尾（边缘侧，已掠过）→ 长拖尾
float wave_head(float s) {
	float K_FRONT = 520.0;  // 前缘陡（半高 ~2.3 格）
	float K_BACK  = 70.0;   // 后缘拖尾（半高 ~6 格）
	return s > 0.0 ? exp(-s * s * K_FRONT) : exp(-s * s * K_BACK);
}

// 单侧两道波（A 主 + B 半周期错开），返回该列波强度（0~1）
// dir=+1 蓝波向右推 / dir=-1 红波向左推；origin 屏外起点，target 中央侧终点
float wave_side(float x, float phase, float dir, float origin, float target) {
	float cA = fract(phase);
	float cB = fract(phase + 0.5);
	float posA = mix(origin, target, cA);
	float posB = mix(origin, target, cB);
	// 生命周期包络：c∈[0,0.12] 淡入，[0.80,1.0] 淡出
	float envA = smoothstep(0.0, 0.12, cA) * (1.0 - smoothstep(0.80, 1.0, cA));
	float envB = smoothstep(0.0, 0.12, cB) * (1.0 - smoothstep(0.80, 1.0, cB));
	float sA = (x - posA) * dir;
	float sB = (x - posB) * dir;
	return max(wave_head(sA) * envA, wave_head(sB) * envB);
}

// 每格中心算亮度 L (0~1)
float energy(vec2 cuv, vec2 ci) {
	// 2D 格点 hash（替代旧整行 hash → 颗粒为随机点而非水平长条）
	float cell_hash = fract(sin(dot(ci, vec2(12.9898, 78.233))) * 43758.5453);

	// 1) 底色：盖过越多越亮（flood）+ 2D 格点微颗粒
	//    上限 0.62 → 盖过末态是"饱和亮蓝/红"而非泛白浅色（避免铺满时糊成白）
	float flood = abs(clash_pos - 0.5) * 2.0;
	float L_base = mix(0.35, 0.62, flood) + (cell_hash - 0.5) * 0.05;

	// 2) 大波（推进期主角）：高斯衰减 30 → 波宽 ~10 格多格明暗渐变
	float dl = cuv.x - pulse_l_x;
	float dr = pulse_r_x - cuv.x;
	float L_pulse_l = exp(-dl * dl * 30.0) * pulse_amp;
	float L_pulse_r = exp(-dr * dr * 30.0) * pulse_amp;

	// 3) 中央白柱（僵持期主角）：衰减 8.1 → 对峙发光带宽 ~7-8 格
	float L_center = exp(-abs(cuv.x - clash_pos) * 8.1) * center_amp;

	// 4) 持续涌入小波（非对称浪头 + 生命周期包络）
	float side = step(cuv.x - clash_pos, 0.0);  // 1=蓝侧
	// 纵向振幅调制：sin 波纹起伏 + 格点颗粒（不再水平长条）
	float y_amp = 0.80 + sin(cuv.y * 12.0 + wave_time) * 0.18 + (cell_hash - 0.5) * 0.30;
	float wl = wave_side(cuv.x, phase_l,  1.0, -0.12, 0.58);
	float wr = wave_side(cuv.x, phase_r, -1.0,  1.12, 0.42);
	float dist_l = max(clash_pos - cuv.x, 0.0);
	float dist_r = max(cuv.x - clash_pos, 0.0);
	float L_wave_l = wl * wave_amp * y_amp * smoothstep(0.0, 0.22, dist_l) * side;
	float L_wave_r = wr * wave_amp * y_amp * smoothstep(0.0, 0.22, dist_r) * (1.0 - side);

	// 5) 连击撞击闪：clash_pos 处局部高亮带（每击 hit_flash 脉冲）
	float hit = exp(-abs(cuv.x - clash_pos) * 13.0) * hit_flash;

	// 6) 崩溃全屏光爆发：以 clash_pos 为中心向左右散发的宽光晕，
	//    随 burst 从中央小光团扩展到全屏、并在 burst 后期整体自然衰落（替代旧窄扩散环）
	float glow_w = 0.12 + burst * 1.25;             // 光晕半宽随 burst 扩展到全屏
	float gdist = (cuv.x - clash_pos) / glow_w;
	// fade：burst 0→0.15 淡入、0.55→1.25 淡出 → burst=0（平时/僵持期）完全无 glow，仅崩溃时爆发
	float glow_fade = smoothstep(0.0, 0.15, burst) * (1.0 - smoothstep(0.55, 1.25, burst));
	float glow = exp(-gdist * gdist * 2.2) * glow_fade * 1.25;

	// 7) 初撞涟漪：以 clash_pos 为心，两道【竖直】亮带分别向左 / 右荡开并消散
	//    （竖直保持对波主题、非圆形；两侧对称各一道；仅随 x 变化 → 满高竖线）
	float r_offset = ripple * 0.6;                         // 每道带从中央向外行进 0→0.6（出屏）
	float r_dl = (cuv.x - (clash_pos - r_offset)) / 0.06;  // 向左行进的带（带宽 ~0.06，加宽显格子列）
	float r_dr = (cuv.x - (clash_pos + r_offset)) / 0.06;  // 向右行进的带
	float r_fade = smoothstep(0.0, 0.12, ripple) * (1.0 - ripple); // 起始淡入 + 扩张中消散
	float ripple_ring = max(exp(-r_dl * r_dl), exp(-r_dr * r_dr)) * r_fade * 0.65;

	float L_base_mod = L_base + L_wave_l + L_wave_r;
	float L = max(L_base_mod, max(max(L_pulse_l, L_pulse_r), L_center));
	L = max(L, max(hit, glow));
	L = max(L, ripple_ring);
	return clamp(L * intensity, 0.0, 0.9999);
}

void fragment() {
	vec2 uv = UV + shake;  // 受击 shake：整屏 UV 偏移（幅度小，越界由 energy 平滑延续不穿帮）
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(uv * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float L = energy(cuv, ci);

	// Bayer 抖动后量化：档位边界棋盘交错（复古像素渐变）
	int bx = int(mod(ci.x, 4.0));
	int by = int(mod(ci.y, 4.0));
	float dith = (BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5;  // ≈ -0.47 ~ +0.47
	L = clamp(L + dith * dither_amt / float(levels), 0.0, 0.9999);
	L = floor(L * float(levels)) / float(levels);

	float side = step(cuv.x - clash_pos, 0.0);
	vec3 col = mix(red_color_at(L), blue_color_at(L), side);

	float a = 1.0;
	if (corner_radius > 0.0) {
		// 像素台阶圆角：x 距离乘 aspect 折算到高度等比空间（防椭圆角），圆弧外切掉
		vec2 q = (floor(UV * corner_grid) + vec2(0.5)) / corner_grid;
		vec2 cc = vec2(min(q.x, 1.0 - q.x) * aspect, min(q.y, 1.0 - q.y));
		vec2 cv = vec2(corner_radius) - cc;
		if (cv.x > 0.0 && cv.y > 0.0 && length(cv) > corner_radius) {
			a = 0.0;
		}
	}
	COLOR = vec4(col, a);
}
