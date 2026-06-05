shader_type canvas_item;

// =============================================================
// canvas_env_stars.gdshader  (v10: 粗像素十字星 + 个体不规则"眨眼"闪烁 + seed)
// 作者: Claude (Game Studios) ｜ 用途: scene1 深夜繁星（纯程序化，全屏）
//   ★ v10：回到「每颗星独立随机闪烁」，但换新形式——【多频叠加的不规则眨眼】(scintillation)：
//     三个不同频率正弦叠加 + 每星随机相位 → 亮度忽明忽暗、有快有慢、不规则，
//     像真实星星大气闪烁，明显区别于之前"单一正弦平滑明灭"。去掉潮汐波/漂移。
//     星形状：星核 + 常驻小十字芒(区别浮尘)；seed 每次进场景随机洗牌。
//   目标平台: PC (Windows D3D12 / Forward+)。复杂度: 单层 3×3 邻域纯算术 → 低。
//   渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动）。
// =============================================================

group_uniforms density;
uniform vec2 grid = vec2(32.0, 18.0);                        // 星分布网格(星格数)
uniform float star_amount : hint_range(0.80, 0.999) = 0.95; // 出星阈值(高=星更少)
uniform float center_bias : hint_range(0.0, 0.3) = 0.04;    // 中央密度偏置(0=完全均匀)
uniform float seed : hint_range(0.0, 1000.0) = 0.0;         // 随机种子(脚本每次进场景随机设)
group_uniforms;

group_uniforms look;
uniform vec4 star_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
group_uniforms;

group_uniforms twinkle;  // 个体不规则眨眼(多频叠加+随机相位 → 每星各自忽明忽暗，非单一正弦)
uniform float twinkle_speed : hint_range(0.0, 3.0) = 1.2;   // 闪烁基准速度
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.6;   // 闪烁幅度(越大忽明忽暗越剧烈)
group_uniforms;

group_uniforms sparkle;  // 常驻小十字星芒(形状特征 → 区别于圆形浮尘粒子)
uniform float spike_blocks : hint_range(0.0, 4.0) = 1.6;    // 常驻星芒长度(像素块)
uniform float spike_strength : hint_range(0.0, 1.0) = 0.5;  // 星芒亮度(相对星核)
group_uniforms;

group_uniforms moon_avoid;
uniform vec2 moon_pos = vec2(0.745, 0.16);
uniform float moon_clear : hint_range(0.0, 0.5) = 0.13;
group_uniforms;

group_uniforms edge;  // 四边渐隐留空 → 边缘无锐利亮星被战斗 PostFX 拉成长条
uniform float edge_margin : hint_range(0.0, 0.45) = 0.14;
group_uniforms;

group_uniforms pixelate;
uniform float pixel_grid : hint_range(20.0, 600.0) = 90.0;  // 横向像素格数(宽度计)，越大格越小越精细
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

// 单颗星(density cell)对当前像素块(bcell)的亮度贡献(静止 + 不规则眨眼)。
float star_contrib(vec2 cell, vec2 bcell, vec2 pg) {
	vec2 sc = cell + seed;
	vec2 star_in = hash22(sc + 7.7);
	vec2 star_uv = (cell + star_in) / grid;
	float amount = clamp(star_amount + center_bias * distance(star_uv, vec2(0.5)), 0.0, 0.999);
	float present = step(amount, hash21(sc + 1.3));
	vec2 star_bcell = floor(star_uv * pg);
	float base_b = mix(0.4, 1.0, hash21(sc + 9.1));

	vec2 dcell = bcell - star_bcell;
	float adx = abs(dcell.x);
	float ady = abs(dcell.y);
	float core = step(adx, 0.5) * step(ady, 0.5);
	// 常驻小十字芒(固定形状)
	float harm = step(ady, 0.5) * step(0.5, adx) * (1.0 - smoothstep(0.0, spike_blocks + 0.001, adx));
	float varm = step(adx, 0.5) * step(0.5, ady) * (1.0 - smoothstep(0.0, spike_blocks + 0.001, ady));
	float shape = core + (harm + varm) * spike_strength;

	// 个体不规则眨眼：三频叠加 + 每星随机相位/速度 → 忽明忽暗、有快有慢
	float ph = hash21(sc + 3.3) * 100.0;
	float spd = twinkle_speed * mix(0.6, 1.4, hash21(sc + 4.4));
	float t = TIME * spd + ph;
	float fl = (sin(t) + 0.7 * sin(t * 1.9 + 1.3) + 0.5 * sin(t * 4.3 + 2.7)) / 2.2;  // ~ -1..1 不规则
	float tw = clamp(1.0 + twinkle_depth * fl, 0.0, 2.0);

	return present * shape * base_b * brightness * tw;
}

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;

	vec2 pg = vec2(pixel_grid, pixel_grid / aspect);
	vec2 bcell = floor(UV * pg);
	vec2 buv = (bcell + 0.5) / pg;

	// 3×3 邻域累加 → 常驻星芒延伸出 density 格时不被格边界裁切
	vec2 dcell0 = floor(buv * grid);
	float lum = 0.0;
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			lum += star_contrib(dcell0 + vec2(float(ox), float(oy)), bcell, pg);
		}
	}

	// 远离月亮天区
	vec2 md = buv - moon_pos;
	md.x *= aspect;
	float moon_mask = smoothstep(moon_clear * 0.5, moon_clear, length(md));

	// 四边矩形渐隐遮罩
	vec2 em = smoothstep(vec2(0.0), vec2(edge_margin), buv) * smoothstep(vec2(0.0), vec2(edge_margin), 1.0 - buv);
	float edge_mask = em.x * em.y;

	COLOR = vec4(star_color.rgb, clamp(lum * moon_mask * edge_mask, 0.0, 1.0));
}
