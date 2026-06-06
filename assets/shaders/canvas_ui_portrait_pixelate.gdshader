shader_type canvas_item;

// =============================================================
// canvas_ui_portrait_pixelate.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 头像框内头像「像素化 + posterize」——统一头像与像素边框的颗粒/色阶质感(简约像素感)。
//   pixel_size>0 → 把头像 UV 量化成更大像素块(更"块状")；levels → 颜色分级(海报化)。
//   头像为方图、框为方框，KEEP_ASPECT_COVERED 等价直填 → 无拉伸畸变；配合 TextureRect texture_filter=nearest 出硬边像素。
//   阵亡灰由节点 modulate 叠加(本 shader 不处理状态)。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 极低(1 次采样)。渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

group_uniforms pixel;
uniform float pixel_size : hint_range(0.0, 128.0) = 0.0;   // >0 时块状化的横向格数(0=用源像素+nearest)
uniform float levels : hint_range(2.0, 64.0) = 20.0;       // 颜色分级数(越小越海报化；大=几乎不变)
group_uniforms;

group_uniforms shape;
uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;  // 圆角(与边框一致 → 切掉头像方角)
uniform float pixel_grid : hint_range(8.0, 48.0) = 24.0;   // 圆角像素台阶格数
group_uniforms;

// 像素台阶圆角遮罩：角落圆弧外 → 0(切掉)。
float corner_round_alpha(vec2 uv, float rr, float pg) {
	if (rr <= 0.0) return 1.0;
	vec2 q = (floor(uv * pg) + 0.5) / pg;
	vec2 cc = min(q, vec2(1.0) - q);
	vec2 corner = vec2(rr) - cc;
	if (corner.x > 0.0 && corner.y > 0.0 && length(corner) > rr) {
		return 0.0;
	}
	return 1.0;
}

void fragment() {
	vec2 uv = UV;
	if (pixel_size > 0.5) {
		uv = floor(UV * pixel_size) / pixel_size;  // 量化 UV → 像素块
	}
	vec4 col = texture(TEXTURE, uv);
	col.rgb = floor(col.rgb * levels) / levels;    // posterize 色阶量化
	col.a *= corner_round_alpha(UV, corner_radius, pixel_grid);  // 圆角
	// rgb 用纯纹理(不乘 COLOR，避免 TextureRect 的 incoming COLOR 含纹理→纹理²压黑)；
	// 仅 alpha 跟随 modulate.a → 回合结束半透明能正常淡出，但平时头像保持明亮。
	COLOR = vec4(col.rgb, col.a * COLOR.a);
}
