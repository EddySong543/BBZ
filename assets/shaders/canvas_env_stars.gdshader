shader_type canvas_item;

// =============================================================
// canvas_env_stars.gdshader  (v12: 有机密集细星场 — 银河密度带 + 多亮度档 + 极少星芒)
// 作者: Claude (Game Studios) ｜ 用途: scene1 深夜繁星（纯程序化，全屏）
//   ★ v12（对齐参考 ref16 的和谐夜空）：取代 v11 的「网格均匀 + 每星十字尖芒 + 骤亮 sparkle」——
//     1) 低频 fbm 做「星密度带」→ 星成片聚散(银河感)、非网格规则；
//     2) 细密星格 + 立方偏态亮度 → 海量极小极暗的尘星 + 少量稍亮星(自然层次)；
//     3) 仅最亮的少数星带一丝 1 块微芒(其余纯点) → 细腻、不"图标化"；
//     4) 柔和平滑闪烁(非骤亮)；少量暖白星做色温变化；地平线以下渐隐。
//   目标平台: PC (Windows D3D12 / Forward+)。复杂度: 密度带每像素算 1 次 fbm + 3×3 邻域纯算术 → 低。
//   渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动）。
// =============================================================

group_uniforms density;
uniform vec2 grid = vec2(120.0, 70.0);                       // 细密星格(高→星小而多)
uniform float coverage : hint_range(0.0, 1.0) = 0.55;        // 总体出星比例(被密度带调制)
uniform float band_scale : hint_range(0.5, 6.0) = 1.8;       // 密度带噪声尺度(低→大块聚散·间隙更明显)
uniform float gap_threshold : hint_range(0.0, 1.0) = 0.62;   // 密度带门槛：低于此处完全无星(银河带间隙)
uniform float band_soft : hint_range(0.02, 0.5) = 0.15;      // 门槛过渡软度(小→星团边界更利落)
uniform float seed : hint_range(0.0, 1000.0) = 0.0;          // 随机种子(脚本每次进场景随机设)
group_uniforms;

group_uniforms look;
uniform vec4 star_color : source_color = vec4(0.86, 0.92, 1.0, 1.0);      // 主星色(冷白)
uniform vec4 star_color_warm : source_color = vec4(1.0, 0.94, 0.84, 1.0); // 少量暖白星(色温变化)
uniform float warm_ratio : hint_range(0.0, 0.5) = 0.18;      // 暖白星占比
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float faint_floor : hint_range(0.0, 0.6) = 0.16;     // 最暗尘星亮度下限
group_uniforms;

group_uniforms twinkle;  // 柔和闪烁(平滑呼吸·非骤亮 sparkle)
uniform float twinkle_speed : hint_range(0.0, 3.0) = 0.7;
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.45;
group_uniforms;

group_uniforms spike;  // 仅最亮的少数星带一丝微芒(其余纯点)
uniform float bright_ratio : hint_range(0.0, 0.3) = 0.05;    // 亮星占比(才给微芒)
uniform float spike_strength : hint_range(0.0, 1.0) = 0.3;   // 微芒亮度(相对星核)
group_uniforms;

group_uniforms moon_avoid;
uniform vec2 moon_pos = vec2(0.646, 0.25);
uniform float moon_clear : hint_range(0.0, 0.6) = 0.34;
group_uniforms;

group_uniforms edge;  // 四边 + 地平线渐隐 → 边缘无锐利亮星被战斗 PostFX 拉成长条
uniform float edge_margin : hint_range(0.0, 0.45) = 0.14;
uniform float sky_bottom : hint_range(0.3, 1.0) = 0.7;       // 星分布下界(UV.y·以下渐隐)
uniform float sky_fade : hint_range(0.02, 0.3) = 0.12;       // 下界渐隐跨度
uniform float top_concentration : hint_range(0.0, 1.0) = 0.5; // 下半区相对上半区的星密度(1=上下均匀·小=越往下越稀·星集中上半夜空·恒>0 下半仍有星)
group_uniforms;

group_uniforms pixelate;
uniform float pixel_grid : hint_range(20.0, 800.0) = 480.0;  // 横向像素格数(大→星更小更精细)
group_uniforms;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
vec2 hash22(vec2 p) {
	float n = hash21(p);
	return fract(vec2(hash21(p + n), hash21(p + n + 1.7)));
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
// 每 octave 旋转 ~37° → 打破 value noise 的轴对齐方块
const mat2 ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.6;
	for (int i = 0; i < 3; i++) {
		v += amp * vnoise(p);
		p = ROT * p * 2.03 + vec2(7.3, 11.7);
		amp *= 0.5;
	}
	return v;
}

// 单个 density 格对当前像素块 bcell 的 (冷星亮度, 暖星亮度) 贡献。dens=该处密度带值(0..1)。
vec2 star_contrib(vec2 cell, vec2 bcell, vec2 pg, float dens, float vweight) {
	vec2 sc = cell + seed;
	vec2 star_in = hash22(sc + 7.7);
	vec2 star_uv = (cell + star_in) / grid;

	// 密度带「门槛 gate」：低于阈值的天区完全无星(留出银河间隙) → 星成团洒落、非铺满
	float band = smoothstep(gap_threshold, gap_threshold + band_soft, dens);
	// vweight = 垂直浓度(上半区=1·下半区平滑减小但>0) → 仅减星数·不减亮度·不形成明显分界
	float prob = coverage * band * vweight;
	float present = step(1.0 - prob, hash21(sc + 1.3));

	// 亮度档：立方偏态 → 绝大多数极暗尘星、少数稍亮
	float r = hash21(sc + 9.1);
	float base_b = mix(faint_floor, 1.0, r * r * r);
	float bright = step(1.0 - bright_ratio, r);   // 仅最亮的少数(才给微芒)

	vec2 star_bcell = floor(star_uv * pg);
	vec2 dcell = bcell - star_bcell;
	float adx = abs(dcell.x);
	float ady = abs(dcell.y);
	float core = step(adx, 0.5) * step(ady, 0.5);
	// 微芒：仅亮星·1 块十字臂(硬边·整格满亮)
	float arm = (step(ady, 0.5) * step(0.5, adx) * step(adx, 1.5)
	           + step(adx, 0.5) * step(0.5, ady) * step(ady, 1.5)) * bright * spike_strength;

	// 柔和闪烁(平滑·每星独立相位/速度)
	float ph = hash21(sc + 3.3) * 6.2831853;
	float spd = twinkle_speed * mix(0.6, 1.4, hash21(sc + 4.4));
	float wave = sin(TIME * spd + ph) * 0.5 + 0.5;
	float tw = (1.0 - twinkle_depth) + twinkle_depth * wave;

	float lum = present * (core + arm) * base_b * brightness * tw;
	float warm = step(1.0 - warm_ratio, hash21(sc + 5.5));   // 该星是否暖白
	return vec2(lum * (1.0 - warm), lum * warm);
}

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;

	vec2 pg = vec2(pixel_grid, pixel_grid / aspect);
	vec2 bcell = floor(UV * pg);
	vec2 buv = (bcell + 0.5) / pg;

	// 密度带：每像素算一次(低频·邻域内近似不变 → 省去 9 次 fbm)
	float dens = clamp(fbm(buv * band_scale + vec2(seed * 0.13, seed * 0.07)) * 1.3, 0.0, 1.0);

	// 垂直浓度：上半夜空满密度·向地平线平滑减到 top_concentration(不为 0) → 星集中上半区、下半留给粒子但仍有星
	float vgrad = mix(top_concentration, 1.0, smoothstep(sky_bottom, 0.0, buv.y));

	// 性能：每颗星落点 star_uv=(cell+star_in)/grid·star_in∈[0,1)·占 1 个 pixel_grid 块，
	// 该块必落在自身 cell 的块区间内 → 当前像素只需查自己所在 cell(无需 3×3 邻域)，算力降至 ~1/9·画面不变。
	vec2 dcell0 = floor(buv * grid);
	vec2 acc = star_contrib(dcell0, bcell, pg, dens, vgrad);   // (冷星亮度, 暖星亮度)

	// 远离月亮天区
	vec2 md = buv - moon_pos;
	md.x *= aspect;
	float moon_mask = smoothstep(moon_clear * 0.5, moon_clear, length(md));

	// 四边渐隐 + 地平线以下渐隐
	vec2 em = smoothstep(vec2(0.0), vec2(edge_margin), buv) * smoothstep(vec2(0.0), vec2(edge_margin), 1.0 - buv);
	float edge_mask = em.x * em.y;
	float sky_mask = smoothstep(sky_bottom, sky_bottom - sky_fade, buv.y);

	float mask = moon_mask * edge_mask * sky_mask;
	float cold = clamp(acc.x, 0.0, 1.0) * mask;
	float warm = clamp(acc.y, 0.0, 1.0) * mask;
	float a = clamp(cold + warm, 0.0, 1.0);
	// 冷/暖按各自亮度加权混色(同一像素通常只一颗星贡献)
	vec3 col = (star_color.rgb * cold + star_color_warm.rgb * warm) / max(cold + warm, 0.0001);
	COLOR = vec4(col, a);
}
