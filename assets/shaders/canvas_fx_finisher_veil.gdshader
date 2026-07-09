shader_type canvas_item;

// =============================================================
// canvas_fx_finisher_veil.gdshader
// 作者: Claude (Game Studios) ｜ 用途: battle_screen 终结演出背景虚化幕（2026-07-09 Eddy 批 Q2B）
//   斩杀拍演出期间盖在舞台之上、双雄（WorldGroup）之下：把背景模糊+压暗+微去饱和，
//   让被拉出的两名英雄独占焦点（参考暗黑地牢判定演出）。
//   ⚠ 性能纪律：节点平时 visible=false + BackBufferCopy DISABLED = 零成本；
//     仅终结演出 ~2s 内存在。9 采样手动展开（规范：循环内禁纹理读取）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 每像素 9 次屏幕采样 → 一次性演出可接受。
// 无变体/关键字。
// =============================================================

uniform float strength : hint_range(0.0, 1.0) = 0.0;   // 演出强度（0=无效果·由 tween 驱动淡入淡出）
uniform float blur_px : hint_range(0.0, 8.0) = 3.5;    // 满强度模糊半径（屏幕 px）
uniform float darken : hint_range(0.0, 1.0) = 0.45;    // 满强度压暗比例
uniform float desat : hint_range(0.0, 1.0) = 0.35;     // 满强度去饱和比例
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;


void fragment() {
	vec2 o = SCREEN_PIXEL_SIZE * blur_px * strength;
	// 3×3 均值模糊（手动展开）
	vec3 col = texture(screen_tex, SCREEN_UV + vec2(-o.x, -o.y)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(0.0, -o.y)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(o.x, -o.y)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(-o.x, 0.0)).rgb
			+ texture(screen_tex, SCREEN_UV).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(o.x, 0.0)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(-o.x, o.y)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(0.0, o.y)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(o.x, o.y)).rgb;
	col /= 9.0;
	// 去饱和 + 压暗（背景退场·聚光留给双雄）
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g), desat * strength);
	col *= 1.0 - darken * strength;
	COLOR = vec4(col, 1.0);
}
