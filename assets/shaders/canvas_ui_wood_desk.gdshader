shader_type canvas_item;
// 木桌衬底（道具图鉴卷轴层下·2026-07-13·v2 去地板感）：深暖胡桃漆面书案——
// 宽板少缝（⛔砖式错缝=地板语言·已删）+ 桌沿框线（读作案沿）+ 漆面光泽横带（色阶化）
// + 板内拉伸木纹（4 色阶量化）+ 暗角（有序抖动防带状）。
// 全程序化零贴图（菜单三牌 shader 母题同路数）；像素块由 pixel_grid 量化（480≈4px 块）。
// ⚠ 静态单层全屏·无逐帧动画——不踩「全屏 shader 叠加」性能黑洞。

uniform float pixel_grid : hint_range(120.0, 960.0) = 480.0;   // 横向像素块数（480=4px 块）
uniform vec3 wood_base : source_color = vec3(0.32, 0.20, 0.11);    // 暖胡桃漆面基色
uniform float plank_rows : hint_range(3.0, 24.0) = 5.0;        // 横板行数（桌面=宽板少缝）
uniform float grain_amt : hint_range(0.0, 0.3) = 0.10;         // 木纹强度
uniform float vignette : hint_range(0.0, 0.6) = 0.28;          // 暗角强度
uniform float rail_px : hint_range(0.0, 60.0) = 24.0;          // 桌沿框宽（屏幕px·0=关）
uniform float sheen_amt : hint_range(0.0, 0.2) = 0.07;         // 漆面光泽带强度

float hash1(float n) {
	return fract(sin(mod(n, 289.0) * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	p = mod(p, 289.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// 像素量化（16:9 → 纵向块数=横向×0.5625）
	vec2 grid = vec2(pixel_grid, pixel_grid * 0.5625);
	vec2 puv = (floor(UV * grid) + 0.5) / grid;

	// 横板：行号→板间明度微差
	float row = floor(puv.y * plank_rows);
	float rowh = hash1(row + 3.7);

	// 板内木纹：x 向拉伸双八度值噪声 → 4 色阶量化（拒绝平滑渐变）
	float g = vnoise(vec2(puv.x * 7.0 + rowh * 31.0, row * 2.0 + puv.y * plank_rows * 1.5));
	g = g * 0.62 + 0.38 * vnoise(vec2(puv.x * 19.0 + rowh * 53.0, row * 5.0 + puv.y * plank_rows * 3.0));
	g = floor(g * 4.0) / 4.0;
	vec3 col = wood_base * (0.92 + (rowh - 0.5) * 0.12) * (1.0 - grain_amt + g * grain_amt * 2.0);

	// 板缝：行边界 1 块细暗线 + 1 块缝下高光（读作板棱）——通长直缝·⛔无错位接头（错缝=地板）
	float blk_y = plank_rows / grid.y;            // 一块占一板的比例
	float fy = fract(puv.y * plank_rows);
	if (fy < blk_y * 1.0) {
		col *= 0.62;
	} else if (fy < blk_y * 2.0) {
		col *= 1.08;
	}

	// 漆面光泽：上三分之一一条宽反光带（3 档色阶化·拒绝平滑渐变）——桌面上过漆的读法
	float sheen = 1.0 - smoothstep(0.02, 0.30, abs(puv.y - 0.30));
	sheen = floor(sheen * 3.0) / 3.0;
	col *= 1.0 + sheen * sheen_amt;

	// 桌沿框：四周一圈暗框线+内侧细高光（读作案沿·家具而非地板的关键提示）
	vec2 px = puv * vec2(1920.0, 1080.0);
	float dpx = min(min(px.x, 1920.0 - px.x), min(px.y, 1080.0 - px.y));
	if (dpx < rail_px) {
		col *= 0.52;
	} else if (dpx < rail_px + 4.0) {
		col *= 1.14;
	}

	// 暗角（中心略上=卷轴焦点）·2×2 有序抖动打散色带
	float d = distance(puv, vec2(0.5, 0.46));
	float vig = smoothstep(0.34, 0.86, d) * vignette;
	float dith = mod(floor(UV.x * grid.x) + mod(floor(UV.y * grid.y), 2.0), 2.0) - 0.5;
	vig = clamp(vig + dith * 0.03, 0.0, 1.0);
	col *= 1.0 - vig;

	COLOR = vec4(col, 1.0);
}
