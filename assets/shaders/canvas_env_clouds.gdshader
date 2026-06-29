shader_type canvas_item;

// =============================================================
// canvas_env_clouds.gdshader  (v4: 柔和月光薄云 — 半透明丝缕)
// 作者: Claude (Game Studios) ｜ 用途: scene1 月夜薄云（全屏层，月之上 → 月光透过的丝缕）
//   ★ v4（取代 v3 的「粗像素硬边色块·不透明遮蔽」——那是"脏"的根源）：
//     1) smoothstep 软边羽化(非 step 硬切) → 云是渐隐的丝缕、非实心块；
//     2) 低不透明上限(半透明) → 星/月透过薄云仍可见，绝不实心遮蔽；
//     3) 靠近月亮的云被月光照亮(冷白)、远处沉入夜色 → "月光薄云"的方向感；
//     4) 极缓横向飘动 + 域扭曲 fbm 自然云形；上部浓、往地平线渐隐(云在天空不在地面)。
//   目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、~6 次噪声、无纹理采样 → 低-中。
//   渲染管线: Godot 4.7 Forward+（2D canvas_item，alpha 混合，TIME 驱动飘动）。
// =============================================================

group_uniforms look;
uniform vec4 cloud_color : source_color = vec4(0.15, 0.20, 0.31, 1.0);     // 云体(夜色暗丝·略亮于天空底)
uniform vec4 cloud_color_lit : source_color = vec4(0.50, 0.60, 0.74, 1.0); // 月光照亮的云(冷白·靠月处)
uniform float coverage : hint_range(0.0, 1.0) = 0.54;     // 云量阈值(高=云更少更薄)
uniform float softness : hint_range(0.05, 0.6) = 0.30;    // 软边羽化跨度(大→丝缕更柔更朦胧·小→更聚拢)
uniform float opacity : hint_range(0.0, 1.0) = 0.42;      // 不透明上限(低=半透明·星月透过可见)
group_uniforms;

group_uniforms moonlight;  // 靠近月亮的云被照亮 → 月光薄云的方向感(月位需与星/月晕同步)
uniform vec2 moon_pos = vec2(0.646, 0.25);
uniform float moon_radius : hint_range(0.1, 1.2) = 0.6;   // 月光晕染半径(此范围内云渐亮)
uniform float moon_boost : hint_range(0.0, 1.5) = 1.0;    // 月光照亮强度(0=云不被照亮)
group_uniforms;

group_uniforms shape;
uniform vec2 cloud_scale = vec2(2.6, 4.0);                // 噪声尺度(x<y → 横向拉伸的层云)
uniform float drift_speed : hint_range(0.0, 0.05) = 0.006; // 飘动速度(极缓)
uniform float warp_amount : hint_range(0.0, 1.5) = 0.6;   // 域扭曲强度(打散网格·云形更自然)
uniform float top_bias : hint_range(0.0, 1.0) = 0.42;     // 云集中带(此 UV.y 以上浓)
uniform float fade_span : hint_range(0.05, 0.8) = 0.55;   // 向下渐隐跨度
uniform float seed : hint_range(0.0, 1000.0) = 0.0;       // 随机种子(脚本每次进场景随机设→云形不同)
group_uniforms;

group_uniforms pixelate;
uniform float pixel_grid : hint_range(20.0, 800.0) = 240.0; // 横向像素格数，越大格越小越精细(薄云宜细)
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

	// 细像素块网格(UV 方格、aspect 校正 → 每格屏幕上为正方形)；网格细 + 软 alpha → 薄云不显方块
	vec2 pg = vec2(pixel_grid, pixel_grid / aspect);
	vec2 puv = (floor(UV * pg) + 0.5) / pg;

	vec2 uv = puv * cloud_scale + vec2(TIME * drift_speed + seed, seed * 0.7);
	// 轻度域扭曲：用低频噪声扰动采样坐标，进一步打散残留网格规则性
	vec2 warp = vec2(noise(uv * 0.5 + 13.1), noise(uv * 0.5 + 41.7)) - 0.5;
	float n = fbm(uv + warp * warp_amount);

	// 软边羽化(smoothstep 非 step → 丝缕渐隐·无硬块)；密度即丝缕浓度
	float density = smoothstep(coverage, coverage + softness, n);

	// 月光照亮：靠月亮的云区渐亮(冷白)、远处沉入夜色 → "月光薄云"方向感
	vec2 md = puv - moon_pos;
	md.x *= aspect;
	float moon_lit = clamp(smoothstep(moon_radius, 0.0, length(md)) * moon_boost, 0.0, 1.0);
	vec3 col = mix(cloud_color.rgb, cloud_color_lit.rgb, moon_lit);

	// 上部浓、往地平线方向渐隐(云在天空不在地面)
	float vmask = smoothstep(top_bias, top_bias - fade_span, puv.y);
	float a = density * vmask * opacity;
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
