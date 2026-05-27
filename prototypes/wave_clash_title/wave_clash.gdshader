shader_type canvas_item;

// ── 波波攒 · 对波加载界面 背景层 shader（原型 · 网格纯色版）─────────────────
// 机制：把屏幕切成固定方格（横 cells_x 格，格高按 aspect 算出 → 正方形）。
// 每个片元先把 UV【吸附到所在格子的中心点】，整格只用该中心点算一次颜色、填成纯色。
// 一格 = 一块纯色：格内无渐变 / 无抗锯齿 / 无抖动。波纹靠整格整格切换颜色表现。
// 不使用任何贴图采样 → 在原生分辨率直接输出方块，不存在放大平滑问题。
// 左蓝 / 右红 竖直波列在 clash_pos 处对撞；clash_pos 由脚本驱动（僵持→盖过）。仅原型用。

uniform float clash_pos : hint_range(0.0, 1.0) = 0.5;   // 对波边界（UV.x）
uniform float aspect = 1.777;                            // 宽高比（算正方形格高 + 暗角）
uniform float cells_x = 24.0;                            // 横向格数（粗细旋钮）
uniform float intensity : hint_range(0.0, 2.0) = 1.0;    // 总强度（淡入 / 盖过闪光）
uniform float edge_jitter : hint_range(0.0, 2.0) = 1.0;  // 边界抖动（盖过时收紧）
uniform float wave_freq = 9.0;                           // 竖直波列密度（按格数语义）
uniform float wave_speed = 3.0;                          // 波列推进速度
uniform int color_levels : hint_range(2, 64) = 14;       // 色阶量化（限色纯块，无抖动）
uniform vec4 blue_color : source_color = vec4(0.18, 0.55, 1.0, 1.0);
uniform vec4 red_color  : source_color = vec4(1.0, 0.27, 0.16, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return s;
}

// 用（已吸附到格心的）uv 算该格的单一纯色。
vec3 field(vec2 uv) {
	// 竖直对波边界（带轻微纵向电弧抖动）
	float jit = (fbm(vec2(uv.y * 5.0, TIME * 0.7)) - 0.5) * 2.0;
	float bx = clash_pos + jit * 0.02 * edge_jitter;
	float d = uv.x - bx;                  // <0 蓝侧 / >0 红侧

	float front_l = exp(min(d, 0.0) * 5.0);
	float front_r = exp(min(-d, 0.0) * 5.0);

	// 竖直波列：相位只依赖横向 x（+ 极轻 y 扰动），随时间向中心推进
	float wob = sin(uv.y * 8.0 + TIME * 1.5) * 0.012;
	float ph_l = (uv.x + wob) * wave_freq - TIME * wave_speed;
	float ph_r = (1.0 - uv.x + wob) * wave_freq - TIME * wave_speed;
	float band_l = pow(0.5 + 0.5 * sin(ph_l), 2.5);
	float band_r = pow(0.5 + 0.5 * sin(ph_r), 2.5);

	float side = step(d, 0.0);            // 硬边：1 蓝侧 / 0 红侧（无 smoothstep）
	float flood = abs(clash_pos - 0.5) * 2.0;
	float base_fill = mix(0.28, 0.72, flood);   // 抬高两侧底色 → 整体更亮

	float blue_amt = side * (base_fill + (0.25 + 0.9 * band_l) * front_l);
	float red_amt  = (1.0 - side) * (base_fill + (0.25 + 0.9 * band_r) * front_r);

	float core = exp(-abs(d) * 40.0);     // 白热缝（按格采样后呈纯白格列）
	float glow = exp(-abs(d) * 8.0);

	vec3 col = vec3(0.02, 0.02, 0.05);
	col += blue_color.rgb * blue_amt * 1.6;
	col += red_color.rgb  * red_amt  * 1.6;
	col += mix(blue_color.rgb, red_color.rgb, side) * glow * 0.5;
	col += vec3(1.0, 0.95, 0.85) * core * 2.0;

	float vig = clamp(1.0 - length((uv - 0.5) * vec2(aspect, 1.0)) * 0.45, 0.0, 1.0);  // 暗角减弱
	col *= vig;
	col *= intensity;

	// 色阶量化（无抖动）→ 干净限色纯块
	col = floor(col * float(color_levels)) / float(color_levels);
	return col;
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / aspect);   // 正方形格
	vec2 cuv = (floor(UV * grid) + 0.5) / grid;    // 吸附到格子中心
	COLOR = vec4(field(cuv), 1.0);                 // 整格填同一纯色
}
