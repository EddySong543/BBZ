shader_type canvas_item;

// 全局「波幕」转场（TransitionManager 专用）：
// 单色像素波从一侧涌入盖屏（progress 0→1），再朝同方向排走露出新场景（1→2）。
// 波体内部 = v3 对波解剖波列（爆亮芯+色鞘·2026-07-17 与 boot 同步·旧双正弦条纹退役），
// 沿推进方向流动；前/后缘 = 多频起伏浪头 + 浪尖白边。大格像素量化，与 boot 对波同语系。

uniform float progress : hint_range(0.0, 2.0) = 0.0; // 0→1 涌入盖屏；1→2 排走揭幕
uniform float dir = 1.0;             // 1 = 左→右；-1 = 右→左（继承 boot 胜方推进方向）
uniform float aspect = 1.777;
uniform float cells_x = 64.0;        // 像素大格列数（与 boot 波一致）
uniform float wave_amp = 0.07;       // 前/后缘起伏振幅（UV）
uniform float wave_time = 0.0;       // 动画相位（gd 每帧推进）
uniform vec3 deep_color : source_color = vec3(0.10, 0.22, 0.48);  // 波体暗档
uniform vec3 crest_color : source_color = vec3(0.36, 0.64, 1.0);  // 浪头亮档（= BootResult.dip_color）
uniform float levels = 7.0;          // 亮度量化档数（像素 ramp 感）
uniform float body_min = 0.15;       // 波体底档（2026-07-17 0.55→0.15：v3 暗场家族——底暗·亮只留芯/浪尖。
                                     //  ⛔旧亮幕决定 2026-06-10 随 v3 作废·deep 压暗同步在 transition_manager）
uniform float body_max = 0.88;       // 波体纹理亮度上限（0.95→0.88·鞘/丝顶亮让位浪尖白边）

// v3 波列剖面常量（2026-07-17 二版·一版被 Eddy 打回："3 道宽鞘=大平板+孤线读作接缝·
// 宽渐变 7 档量化出条带"。二版=波列加密 5 道+鞘收紧 ~3 格（渐变跨度小于条带阈）
// +芯让位浪尖白边+每行能量丝疾行——快速掠过时找回"波体在涌"的密度）
const int BODY_WAVES = 5;            // 幕体内同时的波前道数
const float K_CORE = 4200.0;         // 爆亮芯（半宽 ~1 格）
const float K_SHEATH = 260.0;        // 色鞘拖尾（半宽 ~3.3 格·紧鞘防宽条带）
const float BODY_FLOW = 0.30;        // 波列沿推进方向流速（周期/s·随 wave_time）
const float CORE_TOP = 0.90;         // 芯峰值占亮度区间比（最白只留给浪尖白边）
const float CRACKLE_HZ = 6.0;        // 芯沿逐行碎抖整档步进频率（boot 同语言·防连续噪闪）
const float CRACKLE_AMP = 0.007;     // 碎抖幅度（uv）
const float FLOW_DENSITY = 0.30;     // 能量丝行激活率（幕体密一点=涌感）
const float FLOW_LEN = 0.06;         // 能量丝拖尾长（uv）
const float FLOW_BRIGHT = 0.55;      // 能量丝亮度（占鞘档比）
const float DEAD = 0.06;             // 死区裁尾（v3 纪律·幕体底保持安静）

float dz(float v) {
	return max(v - DEAD, 0.0) / (1.0 - DEAD);
}

float hash11(float n) {
	return fract(sin(n) * 43758.5453);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float edge_wave(float y, float t, float seed) {
	return sin(y * 16.0 + t * 3.1 + seed) * 0.55
		 + sin(y * 6.3 - t * 2.2 + seed * 1.7) * 0.45;
}

void fragment() {
	vec2 cell = vec2(cells_x, max(cells_x / aspect, 1.0));
	vec2 uv = (floor(UV * cell) + 0.5) / cell;
	float xp = dir > 0.0 ? uv.x : 1.0 - uv.x;
	// 前缘（盖屏推进）与后缘（揭幕排走），各自独立起伏；振幅余量保证 0/2 时完全离屏
	float span = 1.0 + 2.0 * wave_amp;
	float front = min(progress, 1.0) * span - wave_amp + edge_wave(uv.y, wave_time, 0.0) * wave_amp;
	float back = max(progress - 1.0, 0.0) * span - wave_amp + edge_wave(uv.y, wave_time, 5.0) * wave_amp;
	float inside = step(xp, front) * step(back, xp);

	// 波体内部（二版）：v3 波列（芯+紧鞘·芯沿逐行碎抖）+ 每行能量丝疾行——
	// 幕体底=body_min 安静档·纹理只在能量体上·最白留给浪尖白边。
	float row = floor(uv.y * cell.y);
	float tstep = floor(wave_time * CRACKLE_HZ);
	float jit = (hash21(vec2(row, tstep)) - 0.5) * CRACKLE_AMP;
	float core_acc = 0.0;
	float sheath_acc = 0.0;
	for (int i = 0; i < BODY_WAVES; i++) {
		float c = fract(wave_time * BODY_FLOW + float(i) / float(BODY_WAVES));
		float pos = mix(-0.10, 1.10, c);
		float env = smoothstep(0.0, 0.08, c) * (1.0 - smoothstep(0.88, 1.0, c));
		float s = xp - pos + jit;   // xp 已折算推进方向 → 波列恒沿盖屏方向行进
		core_acc = max(core_acc, dz(exp(-s * s * K_CORE)) * env);
		sheath_acc = max(sheath_acc, dz(exp(-s * s * K_SHEATH)) * step(s, 0.0) * env);
	}
	// 能量丝：该行至多一条沿推进方向疾行的短拖尾（头亮尾淡·boot 同语言）
	float act = step(hash11(row * 7.31 + 3.0), FLOW_DENSITY);
	float spd = 0.35 + 0.30 * hash11(row * 3.17 + 8.0);
	float fprog = fract(wave_time * spd + hash11(row * 9.13 + 13.0));
	float fx = mix(-0.05, 1.05, fprog);
	float fd = xp - fx;
	float streak = act * step(-FLOW_LEN, fd) * step(fd, 0.0) * (1.0 + fd / FLOW_LEN)
			* smoothstep(0.02, 0.10, fprog) * (1.0 - smoothstep(0.85, 1.0, fprog));
	float bspan = body_max - body_min;   // （span 已被前缘行程占用·勿撞名）
	float btex = max(sheath_acc * 0.85, streak * FLOW_BRIGHT);
	float bright = body_min + max(btex, core_acc * CORE_TOP) * bspan;

	// 前/后缘浪头提亮（距边缘越近越亮，盖向 1.0）
	float df = clamp((front - xp) / 0.16, 0.0, 1.0);
	float db = clamp((xp - back) / 0.16, 0.0, 1.0);
	float crest_glow = max(1.0 - df, 1.0 - db);
	bright = mix(bright, 1.0, crest_glow);

	bright = floor(bright * levels + 0.5) / levels;
	vec3 col = mix(deep_color, crest_color, bright);
	// 浪尖白边：最前/最后 ~2 格泛白，勾出浪的轮廓
	float tip = max(step(front - xp, 0.022), step(xp - back, 0.022));
	col = mix(col, vec3(0.95, 0.97, 1.0), tip * 0.55);
	COLOR = vec4(col, inside);
}
