shader_type canvas_item;

// =============================================================
// canvas_env_clouds.gdshader  (v3: 粗像素硬边色块云 — 不透明遮蔽)
// 作者: Claude (Game Studios) ｜ 用途: scene1 月夜像素云（全屏层，月之上 → 遮月/遮星）
//   ★ v3：由「粗像素色块」组成的不透明云(非半透明朦胧)。pixel_grid 量化成大格，
//     step 硬边切云块(无软边羽化)，云心再亮一级 → 像素体积感；有云处完全遮蔽下一层。
//   旋转 fbm + 域扭曲(承袭 v2，打破 value-noise 方格)生成自然云形，横向缓慢飘动；
//   上部天空浓、往地平线方向渐隐(云在天空不在地面)。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、~6 次噪声 → 低-中。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动飘动）。
// =============================================================

group_uniforms look;
uniform vec4 cloud_color : source_color = vec4(0.20, 0.25, 0.38, 1.0);     // 云体(暗块)
uniform vec4 cloud_color_lit : source_color = vec4(0.32, 0.39, 0.54, 1.0); // 云心(亮块，体积感)
uniform float coverage : hint_range(0.0, 1.0) = 0.50;     // 云量阈值(高=云更少)
uniform float core_step : hint_range(0.02, 0.4) = 0.16;   // 云心亮块阈值偏移(大→亮心更小)
uniform float opacity : hint_range(0.0, 1.0) = 1.0;       // 不透明上限(1=完全遮蔽下层)
group_uniforms;

group_uniforms shape;
uniform vec2 cloud_scale = vec2(2.0, 4.5);                 // 噪声尺度(x<y → 横向拉伸的层云)
uniform float drift_speed : hint_range(0.0, 0.1) = 0.012;  // 飘动速度
uniform float warp_amount : hint_range(0.0, 1.5) = 0.6;    // 域扭曲强度(打散网格)
uniform float top_bias : hint_range(0.0, 1.0) = 0.55;      // 云集中带(此 UV.y 以上浓)
uniform float fade_span : hint_range(0.05, 0.6) = 0.3;     // 向下渐隐跨度
uniform float seed : hint_range(0.0, 1000.0) = 0.0;        // 随机种子(脚本每次进场景随机设→云形不同)
group_uniforms;

group_uniforms pixelate;
uniform float pixel_grid : hint_range(20.0, 600.0) = 90.0; // 横向像素格数(宽度计)，越大格越小越精细
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
// 每 octave 旋转 ~37° + 缩放 + 偏移 → 打破 value noise 的方形网格轴对齐
const mat2 ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p = ROT * p * 2.02 + vec2(11.3, 7.9);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;

	// 粗像素块网格(UV 方格、aspect 校正 → 每格屏幕上为正方形) → 整块同色
	vec2 pg = vec2(pixel_grid, pixel_grid / aspect);
	vec2 puv = (floor(UV * pg) + 0.5) / pg;

	vec2 uv = puv * cloud_scale + vec2(TIME * drift_speed + seed, seed * 0.7);
	// 轻度域扭曲：用低频噪声扰动采样坐标，进一步打散残留网格规则性
	vec2 warp = vec2(noise(uv * 0.5 + 13.1), noise(uv * 0.5 + 41.7)) - 0.5;
	float n = fbm(uv + warp * warp_amount);

	// 硬边色块(无羽化 → 实心遮蔽) + 云心亮一级(像素体积感)
	float cloud = step(coverage, n);
	float litcore = step(coverage + core_step, n);
	vec3 col = mix(cloud_color.rgb, cloud_color_lit.rgb, litcore);

	// 上部浓、往地平线方向渐隐(云在天空不在地面)
	float vmask = smoothstep(top_bias, top_bias - fade_span, puv.y);
	float a = cloud * vmask * opacity;
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
