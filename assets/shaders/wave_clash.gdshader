shader_type canvas_item;

// ── 波波攒 · 对波 shader（主菜单 mode_card「匹配对战」卡面用）· v3「对波解剖」─────
//
// 2026-07-17 与 boot（canvas_boot_wave_clash.gdshader）同步为 v3 对波解剖（Eddy：波家族全线同风格）：
//   1) 底场＝暗档能量场：无满屏噪点（底场钉量化档中点 + 能量体死区裁尾 → 零棋盘纹）
//   2) 波身＝竖直波列：每道波前 = 暗缘 + 爆亮芯 + 色鞘 三层；颗粒只在鞘内；波身脉动呼吸
//   3) 流势＝波列间向心流动的能量丝（短拖尾头亮尾淡）
//   4) 撞点＝窄而炽的角力光墙（缘部逐行蠕动）
// 与 boot 文件的差异仅两处：保留 corner_radius 像素台阶圆角（卡面自切）；无火花/电弧节点层。
// 时间轴 uniforms 全套保留（pulse/hit/burst/ripple 卡面虽不用·prototype 与调参兼容）。

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
uniform float ripple : hint_range(0.0, 1.0) = 0.0;
uniform vec2 shake = vec2(0.0);

// 像素台阶圆角遮罩（ModeCard 卡面用·默认 0=关）。
// ⚠ Godot clip_children 不执行父节点自定义 shader → 圆角必须由本层自切。
uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;  // 半径(高度UV比例)
uniform float corner_grid : hint_range(12.0, 200.0) = 88.0; // 台阶量化格数(与框 shader 对齐)

// ── 解剖旋钮（与 boot v3 同值同义·单位 uv 除注明外）────────────────────
const float BASE_DARK = 0.1625;      // 僵持期底场亮度（6.5/40 档中点·⚠改 levels 须重新对档）
const float BASE_FLOOD = 0.6125;     // 盖满后的底场亮度（24.5/40 档中点）
const float K_CORE = 6500.0;         // 波前爆亮芯高斯衰减（半宽 ~0.8 格）
const float K_SHEATH = 90.0;         // 色鞘拖尾衰减（半宽 ~5.6 格）
const float K_RIM = 5000.0;          // 暗缘衰减
const float RIM_AHEAD = 0.018;       // 暗缘在芯前方的距离
const float CORE_GAIN = 2.4;         // 芯亮度增益（× wave_amp·暖白即止·纯白留给光墙）
const float SHEATH_GAIN = 1.5;       // 鞘亮度增益
const float RIM_DARK = 0.55;         // 暗缘压暗量
const float BREATH_AMT = 0.10;       // 波身脉动呼吸幅度
const float BREATH_HZ = 2.6;
const float CRACKLE_HZ = 6.0;        // 芯沿电性碎抖整档步进频率（防连续噪闪）
const float CRACKLE_AMP = 0.008;
const float FLOW_DENSITY = 0.22;     // 能量丝行激活率
const float FLOW_LEN = 0.075;        // 能量丝拖尾长
const float FLOW_BRIGHT = 0.17;
const float WALL_K_CORE = 90.0;      // 角力光墙窄芯
const float WALL_K_HALO = 14.0;
const float WALL_HALO = 0.30;
const float WALL_WOBBLE = 0.010;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

// 死区裁尾：指数长尾低于 DEAD 归零（连续无跳变）——没有它微量尾巴把底场推离档中点=棋盘纹复发。
const float DEAD = 0.06;

float dz(float v) {
	return max(v - DEAD, 0.0) / (1.0 - DEAD);
}

float hash11(float n) {
	return fract(sin(n) * 43758.5453);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// ── 蓝/红 ramp（全波家族同源·决堤/波幕交棒同色）─────
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

// ── 波前三层剖面：x=爆亮芯 y=色鞘(仅波后) z=暗缘(芯前一格) ─────
vec3 front_profile(float s) {
	float core = dz(exp(-s * s * K_CORE));
	float sheath = dz(exp(-s * s * K_SHEATH)) * step(s, 0.0);
	float d = s - RIM_AHEAD;
	float rim = dz(exp(-d * d * K_RIM));
	return vec3(core, sheath, rim);
}

// 单侧波列（A 主 + B 半周期错开），返回三层剖面（分量取 max）
vec3 wave_side(float x, float phase, float dir, float origin, float target, float jit) {
	float cA = fract(phase);
	float cB = fract(phase + 0.5);
	float posA = mix(origin, target, cA);
	float posB = mix(origin, target, cB);
	float envA = smoothstep(0.0, 0.12, cA) * (1.0 - smoothstep(0.80, 1.0, cA));
	float envB = smoothstep(0.0, 0.12, cB) * (1.0 - smoothstep(0.80, 1.0, cB));
	float sA = (x - posA) * dir + jit;
	float sB = (x - posB) * dir + jit;
	return max(front_profile(sA) * envA, front_profile(sB) * envB);
}

// 能量丝：该行一条自外缘流向中线的短拖尾（头亮尾淡·稀疏激活）
float flow_streak(float x, float row, float dir, float origin, float stop_x, float seed) {
	float act = step(hash11(row * 7.31 + seed), FLOW_DENSITY);
	float spd = 0.10 + 0.12 * hash11(row * 3.17 + seed + 5.0);
	float prog = fract(wave_time * spd + hash11(row * 9.13 + seed + 9.0));
	float sx = mix(origin, stop_x, prog);
	float d = (x - sx) * dir;
	float body = step(-FLOW_LEN, d) * step(d, 0.0) * (1.0 + d / FLOW_LEN);
	float env = smoothstep(0.02, 0.10, prog) * (1.0 - smoothstep(0.72, 0.95, prog));
	return act * body * env;
}

float energy(vec2 cuv, vec2 ci) {
	float cell_hash = hash21(ci);
	float tstep = floor(wave_time * CRACKLE_HZ);

	// 1) 底场：暗档能量场（⛔满屏颗粒）；盖过 flood 提亮成饱和阵营色场
	float flood = abs(clash_pos - 0.5) * 2.0;
	float L_base = mix(BASE_DARK, BASE_FLOOD, flood);

	// 2) 推进大波（卡面 pulse_amp=0 不走）：宽鞘 + 前缘亮芯
	float dl = cuv.x - pulse_l_x;
	float dr = pulse_r_x - cuv.x;
	float pl = exp(-dl * dl * 30.0) * 0.80 + exp(-(dl - 0.010) * (dl - 0.010) * 2600.0) * 0.55;
	float pr = exp(-dr * dr * 30.0) * 0.80 + exp(-(dr - 0.010) * (dr - 0.010) * 2600.0) * 0.55;
	float L_pulse = max(pl, pr) * pulse_amp;

	// 3) 撞点角力光墙：窄芯 + 微晕，缘部逐行蠕动
	float wob = (hash21(vec2(ci.y * 3.7, tstep)) - 0.5) * WALL_WOBBLE;
	float dxw = abs(cuv.x - clash_pos + wob);
	float L_wall = (dz(exp(-dxw * WALL_K_CORE)) + dz(exp(-dxw * WALL_K_HALO)) * WALL_HALO) * center_amp;

	// 4) 波列：暗缘 + 爆亮芯 + 色鞘（颗粒只在鞘内·脉动呼吸·近中线让位光墙）
	float side = step(cuv.x - clash_pos, 0.0);
	float jl = (hash21(vec2(ci.y, tstep)) - 0.5) * CRACKLE_AMP;
	float jr = (hash21(vec2(ci.y + 57.0, tstep)) - 0.5) * CRACKLE_AMP;
	vec3 wl = wave_side(cuv.x, phase_l, 1.0, -0.12, 0.58, jl);
	vec3 wr = wave_side(cuv.x, phase_r, -1.0, 1.12, 0.42, jr);
	float grain = 0.75 + cell_hash * 0.50;
	float breath_l = 1.0 - BREATH_AMT * 0.5 + BREATH_AMT * 0.5 * sin(wave_time * BREATH_HZ);
	float breath_r = 1.0 - BREATH_AMT * 0.5 + BREATH_AMT * 0.5 * sin(wave_time * BREATH_HZ + 1.7);
	float near_l = smoothstep(0.0, 0.16, max(clash_pos - cuv.x, 0.0));
	float near_r = smoothstep(0.0, 0.16, max(cuv.x - clash_pos, 0.0));
	float amp_l = wave_amp * breath_l * near_l * side;
	float amp_r = wave_amp * breath_r * near_r * (1.0 - side);
	float L_wave = (wl.x * CORE_GAIN + wl.y * SHEATH_GAIN * grain) * amp_l
			+ (wr.x * CORE_GAIN + wr.y * SHEATH_GAIN * grain) * amp_r;
	float L_rim = wl.z * RIM_DARK * amp_l + wr.z * RIM_DARK * amp_r;

	// 5) 能量丝：波列间向心流动
	float gate = smoothstep(0.05, 0.18, wave_amp);
	float fl = flow_streak(cuv.x, ci.y, 1.0, -0.05, clash_pos - 0.05, 3.0) * side;
	float fr = flow_streak(cuv.x, ci.y, -1.0, 1.05, clash_pos + 0.05, 11.0) * (1.0 - side);
	float L_flow = (fl + fr) * FLOW_BRIGHT * gate;

	// 6) 连击闪 / 光爆 / 涟漪（机制保留·卡面不用）
	float hit = exp(-abs(cuv.x - clash_pos) * 13.0) * hit_flash;
	float glow_w = 0.12 + burst * 1.25;
	float gdist = (cuv.x - clash_pos) / glow_w;
	float glow_fade = smoothstep(0.0, 0.15, burst) * (1.0 - smoothstep(0.55, 1.25, burst));
	float glow = exp(-gdist * gdist * 2.2) * glow_fade * 1.25;
	float r_offset = ripple * 0.6;
	float r_dl = (cuv.x - (clash_pos - r_offset)) / 0.06;
	float r_dr = (cuv.x - (clash_pos + r_offset)) / 0.06;
	float r_fade = smoothstep(0.0, 0.12, ripple) * (1.0 - ripple);
	float ripple_ring = max(exp(-r_dl * r_dl), exp(-r_dr * r_dr)) * r_fade * 0.65;

	float L_body = max(L_base + L_wave + L_flow - L_rim, 0.05);
	float L = max(L_body, max(L_pulse, L_wall));
	L = max(L, max(hit, glow));
	L = max(L, ripple_ring);
	return clamp(L * intensity, 0.0, 0.9999);
}

void fragment() {
	vec2 uv = UV + shake;
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(uv * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float L = energy(cuv, ci);

	// Bayer 抖动后量化（底场已平·抖动只见于能量体渐变处）
	int bx = int(mod(ci.x, 4.0));
	int by = int(mod(ci.y, 4.0));
	float dith = (BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5;
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
