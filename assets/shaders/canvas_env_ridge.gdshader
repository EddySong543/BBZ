shader_type canvas_item;

// =============================================================
// canvas_env_ridge.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 程序化山脊剪影层（scene2「层山峻岭」代码占位）——
//   value-noise 3 倍频 ridged 脊线 + 可选中央山口下凹（桃花源谷口构图）+ 山脚融雾渐变。
//   一个 shader 多层复用（seed/色/幅度各调）→ 层峦叠嶂；美术到位后整层可被贴图替换。
//   静态无 TIME → 零闪烁；整像素格量化（档中点采样·像素画颗粒）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 低（无采样·每像素 3 次 value noise）。
// 渲染管线: Godot 4.7 Forward+（2D canvas_item）。
// =============================================================

group_uniforms shape;
uniform float seed = 7.0;                                  // 换 seed = 换一条山脊
uniform float base_frac : hint_range(0.0, 1.0) = 0.35;     // 脊线基准高度（UV.y·小=高）
uniform float amp : hint_range(0.0, 0.6) = 0.30;           // 脊线起伏幅度
uniform float freq = 3.5;                                  // 主起伏频率（≈山峰数量级）
uniform float sharp : hint_range(0.0, 1.0) = 0.75;         // 峰形锐度（ridged 尖峰混合·峻岭感）
group_uniforms;

group_uniforms valley;
uniform float valley_center : hint_range(0.0, 1.0) = 0.5;  // 山口中心 x（构图焦点）
uniform float valley_width : hint_range(0.01, 1.0) = 0.2;  // 山口半宽
uniform float valley_depth : hint_range(0.0, 1.0) = 0.0;   // 山口下凹深度（0=无山口）
group_uniforms;

group_uniforms color;
uniform vec4 fill_color : source_color = vec4(0.5, 0.6, 0.66, 1.0);   // 山体主色
uniform vec4 base_tint : source_color = vec4(0.72, 0.68, 0.64, 1.0);  // 山脚雾色（向下渐融）
uniform float base_fade : hint_range(0.0, 1.0) = 0.45;     // 融雾起点（相对山体内深度）
uniform float top_light : hint_range(0.0, 0.5) = 0.10;     // 脊顶受光提亮窄带
group_uniforms;

group_uniforms pixel;
uniform float px_size = 4.0;                               // 像素块尺寸
uniform vec2 size_px = vec2(1920.0, 600.0);                // 节点实际尺寸（量化基准）
group_uniforms;


float hash11(float n) {
	// 大数取模防精度漂移（像素特效稳定性铁律）
	return fract(sin(mod(n, 512.0) * 127.1 + seed * 31.7) * 43758.5453);
}

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u);
}

// 3 倍频 ridged 脊线：v→1-|2v-1| 折出尖峰，sharp 控制混入比例
float ridge_h(float x) {
	float n = 0.0;
	float w = 0.5;
	float fq = freq;
	for (int k = 0; k < 3; k++) {
		float v = vnoise(x * fq + float(k) * 17.0);
		v = mix(v, 1.0 - abs(2.0 * v - 1.0), sharp);
		n += v * w;
		w *= 0.5;
		fq *= 2.1;
	}
	n /= 0.875;
	// 中央山口下凹（高斯形·桃花源谷口）
	float d = abs(x - valley_center) / max(valley_width, 1e-4);
	float notch = valley_depth * exp(-d * d * 2.0);
	return clamp(base_frac + amp * (1.0 - n) * 0.35 - amp * n * 0.65 + notch * amp * 1.6, 0.02, 0.98);
}

void fragment() {
	// 整像素格量化 + 档中点采样（防爬缝/半格闪烁）
	vec2 cell_uv = (floor(UV * size_px / px_size) + 0.5) * px_size / size_px;
	float ry = ridge_h(cell_uv.x);
	float inside = step(ry, cell_uv.y);                    // 脊线以下=山体
	float depth_in = clamp((cell_uv.y - ry) / max(1.0 - ry, 1e-4), 0.0, 1.0);
	vec3 col = fill_color.rgb;
	col += vec3(top_light) * (1.0 - smoothstep(0.0, 0.08, depth_in));   // 脊顶受光
	col = mix(col, base_tint.rgb, smoothstep(base_fade, 1.0, depth_in)); // 山脚融雾
	COLOR = vec4(col, fill_color.a * inside);
}
