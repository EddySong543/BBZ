shader_type canvas_item;

// =============================================================
// canvas_ui_soft_shadow.gdshader
// 作者: Claude (Game Studios) ｜ 用途: UI 卡牌柔性投影（ModeCard 三牌阵 2026-06-13）。
//   挂在比卡体略大的 ColorRect 上（置于卡体之下一层）：以圆角矩形 SDF + smoothstep
//   绘制一块下方柔和暗影，把命运牌从动态对波背景里"拔"出来（图形-背景分离）。
//   实心核 = 卡体大小（节点尺寸内缩 softness_px），软边在 [核, 节点边] 间平滑过渡，
//   所以软影完整落在节点内、不被裁。继承父级 modulate.a（入场淡入/侧牌压暗时投影随动）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 纯算术无采样 → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

group_uniforms shadow;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // 投影色（含基础 alpha）
uniform vec2 rect_px = vec2(100.0, 100.0);                           // 本节点像素尺寸
uniform float corner_px : hint_range(0.0, 200.0) = 24.0;            // 实心核圆角（px，匹配卡角）
uniform float softness_px : hint_range(1.0, 64.0) = 16.0;          // 软边宽度（px）= 核相对节点边的内缩
group_uniforms;

// 圆角矩形有符号距离场（中心原点，b=半尺寸，r=圆角半径）。
float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_px;                  // 居中像素坐标
	vec2 b = max(rect_px * 0.5 - vec2(softness_px), vec2(0.0)); // 核内缩=软边宽 → 软边正好填满外圈
	float d = sd_round_box(p, b, corner_px);
	float a = 1.0 - smoothstep(0.0, softness_px, d); // 核内=1，外缘平滑落到 0
	// 乘 COLOR.a：继承父卡 modulate.a（入场淡入 / 侧牌压暗时投影一起变化）
	COLOR = vec4(shadow_color.rgb, shadow_color.a * a * COLOR.a);
}
