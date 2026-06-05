shader_type canvas_item;

// =============================================================
// canvas_ui_pixel_frame.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 英雄头像框(竹节像素框 2b-Y) —— 仅画多层像素边框 + 噪点质感。
//   像素网格多层边框(外暗轮廓 + 中阵营色 + 内深阵营) + 像素噪点。中心透明 → 让满幅头像/底色透出。
//   ★ 四角菱形角饰改由 hero_frame.gd 的 _draw 用矢量 draw_colored_polygon 叠加(更平滑醒目)，
//     shader 不再画角饰。阵营色/状态由 hero_frame.gd 设 uniform。近方形框(aspect≈1)。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 小 quad、少量 hash → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

group_uniforms palette;
uniform vec4 edge_outer : source_color = vec4(0.04, 0.04, 0.06, 1.0);  // 外暗轮廓
uniform vec4 edge_mid : source_color = vec4(0.3, 0.5, 0.85, 1.0);      // 中阵营色(主)
uniform vec4 edge_inner : source_color = vec4(0.15, 0.25, 0.45, 1.0);  // 内深阵营
group_uniforms;

group_uniforms shape;
uniform float pixel_grid : hint_range(12.0, 48.0) = 24.0;  // 像素格数(框宽高，越大格越细)
uniform float border_px : hint_range(1.0, 6.0) = 2.0;      // 中层边框宽(像素格)
uniform float noise_amt : hint_range(0.0, 0.2) = 0.06;     // 像素噪点质感
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	float pg = pixel_grid;
	vec2 cell = floor(UV * pg);

	// 到最近边的整格距(方形 pg×pg)
	float dl = cell.x;
	float dr = pg - 1.0 - cell.x;
	float dt = cell.y;
	float db = pg - 1.0 - cell.y;
	float edge_dist = min(min(dl, dr), min(dt, db));

	vec4 col = vec4(0.0);  // 中心透明 → 头像/底色透出

	// 多层边框：外 1 格暗轮廓 → 中 border_px 格阵营色 → 内 1 格深阵营
	if (edge_dist < 1.0) {
		col = edge_outer;
	} else if (edge_dist < border_px) {
		col = edge_mid;
	} else if (edge_dist < border_px + 1.0) {
		col = edge_inner;
	}

	// 像素噪点质感(透明处 col=0 不受影响)
	col.rgb *= 1.0 + (hash(cell) - 0.5) * noise_amt;

	COLOR = col;
}
