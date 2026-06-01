shader_type canvas_item;

// =============================================================
// post_fx_color_grade.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 战斗世界全屏统一调色（PostFX 层，UI 之下）
//   色彩分级(亮度/对比/饱和/夜色染色) + 暗部·高光分离染色(split-tone 电影感)
//   + 暗角(vignette) + 统一低频颗粒(grain)。把背景程序化层 + 美术 + 像素角色
//   统一进同一片靛蓝午夜。★ 不含任何模糊 → 像素保持锐利。
// 隔离: 仅作用于其下方已绘制的世界(背景+角色)；UI 在更上层绘制，不受影响。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、1 次屏幕采样 → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，配合 BackBufferCopy 读 SCREEN_TEXTURE）。
// =============================================================

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

group_uniforms grade;
uniform float brightness : hint_range(0.5, 1.5) = 0.97;          // 整体亮度（夜→略压暗）
uniform float contrast   : hint_range(0.5, 2.0) = 1.08;          // 对比（略提，夜景更有层次）
uniform float saturation : hint_range(0.0, 2.0) = 0.88;          // 饱和（略降→高级感）
uniform vec3  tint_color : source_color = vec3(0.85, 0.92, 1.10);// 夜色染色（偏冷靛蓝）
uniform float tint_strength : hint_range(0.0, 1.0) = 0.40;
group_uniforms;

group_uniforms split_tone;  // 暗部偏深靛 / 高光偏冷白微金 —— 电影感的来源
uniform vec3  shadow_tint    : source_color = vec3(0.88, 0.94, 1.08);
uniform vec3  highlight_tint : source_color = vec3(1.06, 1.00, 0.90);
uniform float split_strength : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

group_uniforms vignette;
uniform vec3  vignette_color : source_color = vec3(0.012, 0.020, 0.047);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.40;
uniform float vignette_radius   : hint_range(0.3, 1.2) = 0.90;   // 暗角起始半径
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.55;  // 边界软度
group_uniforms;

group_uniforms grain;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.02;       // 统一颗粒强度（很轻）
uniform float grain_scale  : hint_range(0.5, 4.0) = 1.6;
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// 1) 亮度 → 对比(绕 0.5 中灰) → 饱和(绕 luma)
	col *= brightness;
	col = (col - 0.5) * contrast + 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// 2) 夜色染色
	col = mix(col, col * tint_color, tint_strength);

	// 3) 暗部/高光分离染色（按亮度在两个近中性色间插值，乘法→不大改亮度）
	vec3 toned = col * mix(shadow_tint, highlight_tint, clamp(luma, 0.0, 1.0));
	col = mix(col, toned, split_strength);

	// 4) 暗角（贴画幅的椭圆，向 vignette_color 压暗）
	float d = length(SCREEN_UV - 0.5) * 1.4142;
	float vig = smoothstep(vignette_radius, vignette_radius - vignette_softness, d);
	col = mix(mix(vignette_color, col, vig), col, 1.0 - vignette_strength);

	// 5) 统一低频颗粒（静态、极轻 → 让程序化层与美术层颗粒质感一致）
	float g = hash(SCREEN_UV / max(SCREEN_PIXEL_SIZE.y, 1e-5) * 0.01 * grain_scale) - 0.5;
	col += g * grain_amount;

	COLOR = vec4(col, 1.0);
}
