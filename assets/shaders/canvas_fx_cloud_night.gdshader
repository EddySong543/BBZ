shader_type canvas_item;
// 夜色云重映射：把外部云素材锁进场景夜晚调色带。
// 形体（明暗分布）用素材自身的，颜色全由场景决定——按素材亮度在
// 「阴影蓝 shadow_color」与「月光蓝 lit_color」之间取色，
// 保证任何来源的云贴图都与夜空/屋脊黑烟同一套光色语言。
uniform vec4 shadow_color : source_color = vec4(0.10, 0.13, 0.21, 1.0);
uniform vec4 lit_color : source_color = vec4(0.50, 0.62, 0.82, 1.0);
uniform float lum_lo : hint_range(0.0, 1.0) = 0.08;   // 素材亮度≤此值 → 纯阴影色
uniform float lum_hi : hint_range(0.0, 1.0) = 0.35;   // 素材亮度≥此值 → 纯月光色
uniform float lit_gamma : hint_range(0.2, 4.0) = 1.4; // >1 压缩亮部占比（月光更稀贵）
uniform float alpha_max : hint_range(0.0, 1.0) = 1.0; // 整体透明度上限

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float k = pow(smoothstep(lum_lo, lum_hi, lum), lit_gamma);
	COLOR = vec4(mix(shadow_color.rgb, lit_color.rgb, k), t.a * alpha_max);
}
