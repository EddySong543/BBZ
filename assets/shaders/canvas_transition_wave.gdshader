shader_type canvas_item;

// 全局「波幕」转场（TransitionManager 专用）：
// 单色像素波从一侧涌入盖屏（progress 0→1），再朝同方向排走露出新场景（1→2）。
// 波体内部 = 竖波列横向流动纹理（与菜单波流 canvas_env_wave_flow 同语言），不是暗板；
// 前/后缘 = 多频起伏浪头 + 浪尖白边。大格像素量化，与 boot 对波同语系。

uniform float progress : hint_range(0.0, 2.0) = 0.0; // 0→1 涌入盖屏；1→2 排走揭幕
uniform float dir = 1.0;             // 1 = 左→右；-1 = 右→左（继承 boot 胜方推进方向）
uniform float aspect = 1.777;
uniform float cells_x = 64.0;        // 像素大格列数（与 boot 波一致）
uniform float wave_amp = 0.07;       // 前/后缘起伏振幅（UV）
uniform float wave_time = 0.0;       // 动画相位（gd 每帧推进）
uniform vec3 deep_color : source_color = vec3(0.10, 0.22, 0.48);  // 波体暗档
uniform vec3 crest_color : source_color = vec3(0.36, 0.64, 1.0);  // 浪头亮档（= BootResult.dip_color）
uniform float levels = 7.0;          // 亮度量化档数（像素 ramp 感）
uniform float body_min = 0.30;       // 波体纹理亮度下限（防中段过暗）
uniform float body_max = 0.78;       // 波体纹理亮度上限

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

	// 波体内部：竖波列横向流动（双频相位扭曲），身体始终在 body_min~body_max 间呼吸
	float p1 = sin(uv.x * 26.0 - wave_time * 2.6 + sin(uv.y * 8.0 + wave_time * 1.6) * 0.9);
	float p2 = sin(uv.x * 11.0 + wave_time * 1.4 + uv.y * 5.0);
	float body = clamp(0.5 + p1 * 0.28 + p2 * 0.18, 0.0, 1.0);
	float bright = mix(body_min, body_max, body);

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
