shader_type canvas_item;

// =============================================================
// canvas_env_stars.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 深夜「月明星稀」繁星层（纯程序化，全屏）
// 网格分格、每格至多一颗星：hash 决定是否出现 + 格内位置 + 基础亮度 + 闪烁相位。
//   沉静微闪（慢且浅）；自动避开月亮天区；非星区 alpha=0 透出下层。星点即像素，契合像素风。
// 目标平台: PC (Windows D3D12 / Forward+)。
// 复杂度预算: 全屏 1 pass、纯 hash 算术、无纹理采样 —— 开销极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，用 TIME 驱动闪烁）。
// =============================================================

group_uniforms density;
uniform vec2 grid = vec2(32.0, 18.0);                         // 采样网格（列×行，约 16:9）
uniform float star_amount : hint_range(0.80, 0.999) = 0.95;  // 出现阈值（越高星越少；月明星稀→高）
group_uniforms;

group_uniforms look;
uniform vec4 star_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float star_size : hint_range(0.5, 4.0) = 1.6;        // 星点半径（屏幕像素）
uniform float brightness : hint_range(0.0, 2.0) = 0.9;
group_uniforms;

group_uniforms twinkle;
uniform float twinkle_speed : hint_range(0.0, 3.0) = 0.7;    // 闪烁速度（沉静→慢）
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.35;   // 闪烁深度（沉静→浅）
group_uniforms;

group_uniforms moon_avoid;
uniform vec2 moon_pos = vec2(0.745, 0.16);                   // 月心（应与月亮位置一致）
uniform float moon_clear : hint_range(0.0, 0.5) = 0.13;     // 月亮周围清空星的半径
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

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;       // viewport 像素尺寸
	float aspect = vp.x / vp.y;
	vec2 uv = UV;

	// 网格分格：每格至多一颗星
	vec2 gpos = uv * grid;
	vec2 cell = floor(gpos);
	vec2 f = fract(gpos);

	float present = step(star_amount, hash21(cell + 1.3));    // 该格是否有星
	vec2 star_uv = hash22(cell + 7.7);                        // 星在格内的位置 0..1
	float base_b = mix(0.35, 1.0, hash21(cell + 9.1));        // 每颗星基础亮度不同 → 自然
	float phase = hash21(cell + 3.3) * 6.2831;               // 闪烁相位

	// 到星中心的屏幕像素距离 → 圆点
	vec2 cell_px = vp / grid;
	float dist = length((f - star_uv) * cell_px);
	float star = 1.0 - smoothstep(star_size * 0.5, star_size, dist);

	// 沉静微闪
	float tw = 1.0 - twinkle_depth * (0.5 + 0.5 * sin(TIME * twinkle_speed + phase));

	// 远离月亮天区（月亮附近渐隐）
	vec2 md = uv - moon_pos;
	md.x *= aspect;
	float moon_mask = smoothstep(moon_clear * 0.5, moon_clear, length(md));

	float v = present * star * tw * base_b * brightness * moon_mask;
	COLOR = vec4(star_color.rgb, clamp(v, 0.0, 1.0));
}
