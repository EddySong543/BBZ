shader_type canvas_item;

// 菱形头像外框（2026-07-18·ref10 左侧头像语言）：正方形转 45° = L1 范数等值线。
// 内填暗底 + 一圈描边；框外全透明。配 canvas_ui_diamond_mask 收头像下半。
// 像素纪律：px_size 把 UV 量化到成品像素格 → 斜边台阶等宽，不出现半像素毛边。

uniform vec4 fill_color : source_color = vec4(0.09, 0.08, 0.10, 1.0);
uniform vec4 stroke_color : source_color = vec4(0.95, 0.93, 0.85, 1.0);
uniform float stroke_px = 4.0;
// 最外一圈近黑压边：单一亮色描边贴在夜空上显单薄，外面套一圈暗边才立得住
// （同底部按钮 edge_outer 语言·Eddy 2026-07-18「外框太单薄」）。
uniform vec4 rim_color : source_color = vec4(0.1, 0.09, 0.11, 1.0);
uniform float rim_px = 2.0;
uniform vec2 size_px = vec2(72.0, 72.0);
uniform float px_size = 1.0;

void fragment() {
	vec2 uv = UV;
	if (px_size > 1.0) {                       // 量化到像素格（半像素采样=取格心）
		vec2 grid = max(size_px / px_size, vec2(1.0));
		uv = (floor(uv * grid) + 0.5) / grid;
	}
	vec2 half_ext = max(size_px * 0.5, vec2(1.0));
	vec2 p = (uv - 0.5) * size_px;
	float d = abs(p.x) / half_ext.x + abs(p.y) / half_ext.y;   // =1 即菱形边
	// 像素宽度换算到 d 空间（沿两轴的平均法向步长）
	float unit = (1.0 / half_ext.x + 1.0 / half_ext.y) * 0.5;
	float rim_d = rim_px * unit;
	float stroke_d = stroke_px * unit;
	vec4 c;
	if (d > 1.0) {
		c = vec4(0.0);
	} else if (d > 1.0 - rim_d) {
		c = rim_color;                         // 最外：近黑压边
	} else if (d > 1.0 - rim_d - stroke_d) {
		c = stroke_color;                      // 中间：阵营亮边
	} else {
		c = fill_color;
	}
	COLOR = c * COLOR;                         // 乘 modulate（阵亡压灰/选中提亮走它）
}
