shader_type canvas_item;

// =============================================================
// canvas_env_stars.gdshader  (v4: 3×3 邻域 → 星芒跨格不裁切；随机偶发闪烁)
// 作者: Claude (Game Studios) ｜ 用途: scene1 深夜繁星（纯程序化，全屏）
//   每格至多一颗星，每颗都具十字星芒：平时只显"亮点"，按各自随机周期偶发"闪烁"
//   (展开横竖星芒 + 增亮)，满天错开 → 自然随机闪烁，且和飘动浮尘明显区分。
//   ★ v4：fragment 采样 3×3 邻格累加 → 星芒延伸出格时不再被格边界裁掉(修"半边芒")。
//   自动避开月亮天区。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、9 格 hash 算术 → 低-中。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动）。
// =============================================================

group_uniforms density;
uniform vec2 grid = vec2(32.0, 18.0);
uniform float star_amount : hint_range(0.80, 0.999) = 0.95;
group_uniforms;

group_uniforms look;
uniform vec4 star_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float star_size : hint_range(0.5, 4.0) = 1.6;        // 亮点核心半径(像素)
uniform float brightness : hint_range(0.0, 2.0) = 0.9;
group_uniforms;

group_uniforms twinkle;  // 亮点的基础微闪(所有星，持续轻微)
uniform float twinkle_speed : hint_range(0.0, 3.0) = 0.7;
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.35;
group_uniforms;

group_uniforms sparkle;  // 十字星芒 + 随机偶发闪烁
uniform float spike_length : hint_range(2.0, 40.0) = 8.0;        // 星芒长度(像素，闪烁时)
uniform float spike_width : hint_range(0.5, 4.0) = 1.2;          // 星芒粗细(像素)
uniform float flash_min_interval : hint_range(1.0, 20.0) = 8.0;  // 每星闪烁最小间隔(秒)
uniform float flash_max_interval : hint_range(1.0, 30.0) = 24.0; // 最大间隔(与上构成随机区间)
uniform float flash_duration : hint_range(0.05, 0.6) = 0.30;    // 单次闪烁占周期比例(大→更舒缓)
uniform float flash_boost : hint_range(0.0, 3.0) = 0.7;         // 闪烁时增亮倍量
group_uniforms;

group_uniforms moon_avoid;
uniform vec2 moon_pos = vec2(0.745, 0.16);
uniform float moon_clear : hint_range(0.0, 0.5) = 0.13;
group_uniforms;

group_uniforms edge;  // 画面四边留空：每边一条 edge_margin 宽的渐隐带(四角因 x、y 两因子相乘缩得更多) → 边缘无锐利亮星被战斗 PostFX 拉成长条
uniform float edge_margin : hint_range(0.0, 0.45) = 0.14;   // 每边渐隐带宽度(UV比例)；0=星布满到边，越大留空越多
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

// 单颗星(指定网格 cell)对当前像素(全局网格坐标 gpos)的亮度贡献
float star_contrib(vec2 cell, vec2 gpos, vec2 cell_px) {
	float present = step(star_amount, hash21(cell + 1.3));
	vec2 star_uv = hash22(cell + 7.7);
	float base_b = mix(0.35, 1.0, hash21(cell + 9.1));
	float phase = hash21(cell + 3.3) * 6.2831;

	vec2 star_gpos = cell + star_uv;                  // 星的全局网格位置
	vec2 dp = (gpos - star_gpos) * cell_px;           // 当前像素到星的像素偏移(可跨格)
	float dist = length(dp);
	float core = 1.0 - smoothstep(star_size * 0.5, star_size, dist);

	float tw = 1.0 - twinkle_depth * (0.5 + 0.5 * sin(TIME * twinkle_speed + phase));
	float period = mix(flash_min_interval, flash_max_interval, hash21(cell + 5.5));
	float pp = fract(TIME / period + hash21(cell + 8.2));
	float flash = smoothstep(0.0, flash_duration * 0.35, pp)
		* (1.0 - smoothstep(flash_duration * 0.35, flash_duration, pp));

	float len = spike_length * max(flash, 0.001);
	float adx = abs(dp.x);
	float ady = abs(dp.y);
	float sh = (1.0 - smoothstep(0.0, len, adx)) * exp(-(ady * ady) / (spike_width * spike_width));
	float sv = (1.0 - smoothstep(0.0, len, ady)) * exp(-(adx * adx) / (spike_width * spike_width));
	float spikes = (sh + sv) * flash;

	float lum = base_b * brightness;
	return present * (core * tw * (1.0 + flash * flash_boost) + spikes * (1.0 + flash_boost)) * lum;
}

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;
	vec2 uv = UV;

	vec2 gpos = uv * grid;
	vec2 cell0 = floor(gpos);
	vec2 cell_px = vp / grid;

	// 3×3 邻域累加 → 星芒可延伸出本格、不被格边界裁切
	float accum = 0.0;
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			accum += star_contrib(cell0 + vec2(float(ox), float(oy)), gpos, cell_px);
		}
	}

	// 远离月亮天区
	vec2 md = uv - moon_pos;
	md.x *= aspect;
	float moon_mask = smoothstep(moon_clear * 0.5, moon_clear, length(md));

	// 四边矩形遮罩：每边留 edge_margin 宽的渐隐带；四角因 x、y 两因子相乘缩得更多。
	// 边缘无锐利亮星 → 战斗 PostFX 的边缘模糊/畸变没有亮星可拉成长条。
	vec2 em = smoothstep(vec2(0.0), vec2(edge_margin), uv) * smoothstep(vec2(0.0), vec2(edge_margin), 1.0 - uv);
	float edge_mask = em.x * em.y;

	COLOR = vec4(star_color.rgb, clamp(accum * moon_mask * edge_mask, 0.0, 1.0));
}
