shader_type canvas_item;

// =============================================================
// canvas_ui_round_mask.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 给纯色层(如头像框底色 BgFill)切像素台阶圆角——只遮罩 alpha, 颜色用节点自身 color。
//   与 pixel_frame / portrait / inner_fx 同一套圆角逻辑 → 多层方形一起切圆角、不露方角。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 极低。渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;  // 圆角半径(UV比例,0=直角)
uniform float pixel_grid : hint_range(8.0, 48.0) = 24.0;   // 圆角像素台阶格数

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
	COLOR.a *= corner_round_alpha(UV, corner_radius, pixel_grid);
}
