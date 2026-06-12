shader_type canvas_item;

// =============================================================
// canvas_ui_rounded_fill.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 像素台阶圆角填充遮罩（ModeCard 圆角化 2026-06-12）。
//   挂在 ColorRect 上：保留节点自身颜色，仅按像素台阶切掉四角 alpha。
//   配合 clip_children = CLIP_CHILDREN_AND_DRAW 使用 → 子节点（牌面填充/对波美术层）
//   一并被圆角裁剪，对波 shader 本体无需改动。
//   圆角算法与 canvas_ui_pixel_frame.gdshader 的 corner_round_alpha 同源同参——
//   两者用同一 pixel_grid/aspect 量化，台阶逐格对齐不露缝。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 纯算术无采样 → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

group_uniforms shape;
uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;  // 圆角半径(高度UV比例,0=直角)
uniform float pixel_grid : hint_range(12.0, 200.0) = 88.0; // 量化格数(与框 shader 同值=台阶对齐)
uniform float aspect : hint_range(0.1, 10.0) = 1.0;        // 宽/高比：非方形等圆修正
group_uniforms;

// 像素台阶圆角遮罩（canvas_ui_pixel_frame 同源）：角落圆弧外 → 0(切掉)。
float corner_round_alpha(vec2 uv, float rr, float pg, float asp) {
	if (rr <= 0.0) return 1.0;
	vec2 q = (floor(uv * pg) + 0.5) / pg;     // 像素格中心
	vec2 cc = vec2(min(q.x, 1.0 - q.x) * asp, min(q.y, 1.0 - q.y));  // 到最近边的等比距离
	vec2 corner = vec2(rr) - cc;              // 进入角落 rr 区的深度
	if (corner.x > 0.0 && corner.y > 0.0 && length(corner) > rr) {
		return 0.0;
	}
	return 1.0;
}

void fragment() {
	vec4 col = COLOR;  // ColorRect 自身颜色(含 modulate)
	col.a *= corner_round_alpha(UV, corner_radius, pixel_grid, aspect);
	COLOR = col;
}
