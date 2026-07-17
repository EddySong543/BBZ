shader_type canvas_item;

// ── canvas_boot_wave_clash · 波波攒 boot 对波 v3「对波解剖」（2026-07-17·boot_screen 专用）─────
//
// 从 wave_clash.gdshader (v2b) 分叉重构：题材＝能量对波（⛔ 一切水波/浪涛语言）。
// ⚠ 旧 wave_clash.gdshader 仍被主菜单 mode_card「匹配对战」卡面使用——两文件独立、互不影响。
//
// 对波三件套（参考 ArcSys 气功波三层结构 + Beam-O-War 对波演出语法）：
//   1) 底场＝暗档能量场：无满屏噪点、大块安静暗区——暗下来，能量才亮得起来
//   2) 波身＝竖直波列（铁律·非圆环）：每道波前 = 暗缘 + 爆亮芯 + 色鞘 三层；
//      芯沿逐行电性碎抖（整档步进防闪烁·像素特效稳定性教训）；颗粒只在鞘内；波身脉动呼吸
//   3) 流势＝波列间向心流动的能量丝（每行至多一条·短拖尾头亮尾淡）→ 能量涌向前线的方向感
//   4) 撞点＝窄而炽的角力光墙（芯+晕·缘部逐行蠕动）——火花/电弧演出在 clash_fx.gd 节点层
//
// 时间轴 uniforms 与 v2b 完全同名同义（boot_screen.gd 的驱动逻辑零改动）：
//   pulse_l_x / pulse_r_x / pulse_amp : 推进期大波（现带前缘亮芯）
//   center_amp                        : 角力光墙强度（僵持期微脉动）
//   wave_amp / phase_l / phase_r      : 波列振幅与累积相位（盖过期胜方加速）
//   wave_time                         : 全部内部动画的时基（脚本每帧累加）
//   clash_pos / hit_flash / burst / ripple / shake : 中线 / 连击闪 / 决堤光爆 / 涟漪 / 抖动

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

// ── 解剖旋钮（改观感先动这里·单位：uv 除注明外）────────────────────
// ⚠ 底场两档必须钉在量化档中点（= (k+0.5)/levels·levels=40）：Bayer 抖动 ±0.47 档
//   不过档界 → 平坦底场零棋盘纹。改 levels 或这两档时必须重新对档。
const float BASE_DARK = 0.1625;      // 僵持期底场亮度（6.5/40·暗场=对比底）
const float BASE_FLOOD = 0.6125;     // 决堤盖满后的底场亮度（24.5/40·饱和阵营色不泛白）
const float K_CORE = 6500.0;         // 波前爆亮芯高斯衰减（半宽 ~0.8 格）
const float K_SHEATH = 90.0;         // 色鞘拖尾衰减（半宽 ~5.6 格）
const float K_RIM = 5000.0;          // 暗缘衰减
const float RIM_AHEAD = 0.018;       // 暗缘在芯前方的距离（~1.2 格）
const float CORE_GAIN = 2.4;         // 芯亮度增益（× wave_amp·顶到暖白即止——纯白只留给光墙）
const float SHEATH_GAIN = 1.5;       // 鞘亮度增益（× wave_amp × 颗粒）
const float RIM_DARK = 0.55;         // 暗缘压暗量（× wave_amp）
const float BREATH_AMT = 0.10;       // 波身脉动呼吸幅度
const float BREATH_HZ = 2.6;         // 呼吸频率（rad/s）
const float CRACKLE_HZ = 6.0;        // 电性碎抖整档步进频率（Hz·防连续噪闪）
const float CRACKLE_AMP = 0.008;     // 芯沿逐行抖动幅度（~0.5 格）
const float FLOW_DENSITY = 0.22;     // 能量丝行激活率（0~1）
const float FLOW_LEN = 0.075;        // 能量丝拖尾长（~5 格·太短量化后只剩孤点）
const float FLOW_BRIGHT = 0.17;      // 能量丝亮度增量
const float WALL_K_CORE = 90.0;      // 角力光墙窄芯指数衰减（半宽 ~0.5 格）
const float WALL_K_HALO = 14.0;      // 光墙微晕衰减
const float WALL_HALO = 0.30;        // 微晕强度
const float WALL_WOBBLE = 0.010;     // 光墙缘逐行蠕动幅度

// Bayer 4x4 有序抖动矩阵（值 0..15，用于档位边界棋盘交错）
const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

// 死区裁尾：高斯/指数剖面低于 DEAD 的长尾直接归零（连续·无跳变），其余重归一化。
// ⚠ 没有它，各能量体的微量尾巴会把平坦底场推离量化档中点 → Bayer 满屏棋盘纹复发。
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

// ── 蓝色 ramp：5 个关键色之间 mix（与 v2b 完全一致·决堤/波幕交棒同色）─────
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
// s = 沿传播方向的有符号距离：s>0 在波前方（朝中线），s<0 在波后（鞘/拖尾侧）
vec3 front_profile(float s) {
	float core = dz(exp(-s * s * K_CORE));
	float sheath = dz(exp(-s * s * K_SHEATH)) * step(s, 0.0);
	float d = s - RIM_AHEAD;
	float rim = dz(exp(-d * d * K_RIM));
	return vec3(core, sheath, rim);
}

// 单侧波列（A 主 + B 半周期错开），返回三层剖面（分量取 max）
// dir=+1 蓝波向右推 / dir=-1 红波向左推；jit=芯沿逐行电性碎抖
vec3 wave_side(float x, float phase, float dir, float origin, float target, float jit) {
	float cA = fract(phase);
	float cB = fract(phase + 0.5);
	float posA = mix(origin, target, cA);
	float posB = mix(origin, target, cB);
	// 生命周期包络：c∈[0,0.12] 淡入，[0.80,1.0] 淡出
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
	float d = (x - sx) * dir;                              // 0=丝头，负=尾
	float body = step(-FLOW_LEN, d) * step(d, 0.0) * (1.0 + d / FLOW_LEN);
	// 行进包络：起点淡入 + 临近前线淡出（让位光墙）
	float env = smoothstep(0.02, 0.10, prog) * (1.0 - smoothstep(0.72, 0.95, prog));
	return act * body * env;
}

// 每格中心算亮度 L (0~1)
float energy(vec2 cuv, vec2 ci) {
	float cell_hash = hash21(ci);
	float tstep = floor(wave_time * CRACKLE_HZ);   // 整档步进时基（防连续噪闪）

	// 1) 底场：暗档能量场（⛔满屏颗粒）；决堤 flood 时提亮成饱和阵营色场
	float flood = abs(clash_pos - 0.5) * 2.0;
	float L_base = mix(BASE_DARK, BASE_FLOOD, flood);

	// 2) 推进大波（首撞主角）：宽鞘 + 前缘亮芯（首波也要有"形"）
	float dl = cuv.x - pulse_l_x;
	float dr = pulse_r_x - cuv.x;
	float pl = exp(-dl * dl * 30.0) * 0.80 + exp(-(dl - 0.010) * (dl - 0.010) * 2600.0) * 0.55;
	float pr = exp(-dr * dr * 30.0) * 0.80 + exp(-(dr - 0.010) * (dr - 0.010) * 2600.0) * 0.55;
	float L_pulse = max(pl, pr) * pulse_amp;

	// 3) 撞点角力光墙：窄芯 + 微晕，缘部逐行蠕动（活的对峙线）
	float wob = (hash21(vec2(ci.y * 3.7, tstep)) - 0.5) * WALL_WOBBLE;
	float dxw = abs(cuv.x - clash_pos + wob);
	float L_wall = (dz(exp(-dxw * WALL_K_CORE)) + dz(exp(-dxw * WALL_K_HALO)) * WALL_HALO) * center_amp;

	// 4) 波列：暗缘 + 爆亮芯 + 色鞘（颗粒只在鞘内·脉动呼吸·近中线让位光墙）
	float side = step(cuv.x - clash_pos, 0.0);   // 1=蓝侧
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

	// 5) 能量丝：波列间向心流动（能量涌向前线的方向感）
	float gate = smoothstep(0.05, 0.18, wave_amp);
	float fl = flow_streak(cuv.x, ci.y, 1.0, -0.05, clash_pos - 0.05, 3.0) * side;
	float fr = flow_streak(cuv.x, ci.y, -1.0, 1.05, clash_pos + 0.05, 11.0) * (1.0 - side);
	float L_flow = (fl + fr) * FLOW_BRIGHT * gate;

	// 6) 连击闪 / 决堤光爆 / 初撞涟漪（机制同 v2b 原样保留）
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
	vec2 uv = UV + shake;  // 受击 shake：整屏 UV 偏移（幅度小，越界由 energy 平滑延续不穿帮）
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(uv * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float L = energy(cuv, ci);

	// Bayer 抖动后量化：档位边界棋盘交错（底场已平，抖动只见于能量体渐变处）
	int bx = int(mod(ci.x, 4.0));
	int by = int(mod(ci.y, 4.0));
	float dith = (BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5;
	L = clamp(L + dith * dither_amt / float(levels), 0.0, 0.9999);
	L = floor(L * float(levels)) / float(levels);

	float side = step(cuv.x - clash_pos, 0.0);
	vec3 col = mix(red_color_at(L), blue_color_at(L), side);
	COLOR = vec4(col, 1.0);
}
