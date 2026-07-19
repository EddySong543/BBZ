shader_type canvas_item;

// 菱形头像外框（2026-07-18·ref10 左侧头像语言）：正方形转 45° = L1 范数等值线。
// 材质语言复刻 canvas_button_jelly：外暗轮廓 → 亮色凸边 → 连续暗色内描边，
// 边与底都带垂直明暗和低强度像素颗粒，避免纯色矢量边「太光滑」。
// 配 canvas_ui_diamond_mask 收头像下半；框外全透明。

uniform vec4 fill_color : source_color = vec4(0.09, 0.08, 0.10, 1.0);
uniform vec4 stroke_color : source_color = vec4(0.95, 0.93, 0.85, 1.0);
uniform float stroke_px = 4.0;
// 最外一圈近黑压边：单一亮色描边贴在夜空上显单薄，外面套一圈暗边才立得住
// （同底部按钮 edge_outer 语言·Eddy 2026-07-18「外框太单薄」）。
uniform vec4 rim_color : source_color = vec4(0.1, 0.09, 0.11, 1.0);
uniform float rim_px = 2.0;
// 亮边内侧的连续暗描边；宽度从 stroke_px 内部分走，不增加框总厚度。
uniform float inner_rim_px = 1.5;
uniform float noise_amt : hint_range(0.0, 0.3) = 0.08;
uniform float wear : hint_range(0.0, 0.5) = 0.16;
uniform float texture_pixel_px : hint_range(1.0, 4.0) = 2.0;
uniform vec2 size_px = vec2(72.0, 72.0);
uniform float px_size = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

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
	float inner_d = min(inner_rim_px, stroke_px) * unit;
	vec2 cell = floor(uv * size_px / max(texture_pixel_px, 1.0));
	float grain = hash(cell);
	float vertical = clamp(uv.y, 0.0, 1.0);
	vec4 c;
	if (d > 1.0) {
		c = vec4(0.0);
	} else if (d > 1.0 - rim_d) {
		c = rim_color;                         // 最外：近黑压边
	} else if (d > 1.0 - rim_d - stroke_d + inner_d) {
		// 阵营亮边：上亮下暗 + 2px 像素颗粒；少量磨损格只轻压暗，不打断轮廓。
		vec3 edge = stroke_color.rgb * mix(1.10, 0.72, vertical);
		edge *= 1.0 + (grain - 0.5) * noise_amt;
		float wear_dot = step(0.84, hash(cell + vec2(5.1, 2.7)));
		edge *= 1.0 - wear * wear_dot;
		c = vec4(edge, stroke_color.a);
	} else if (d > 1.0 - rim_d - stroke_d) {
		c = rim_color;                         // 亮边内侧：连续暗描边（同底部按钮 solid_rim）
	} else {
		// 暗底也走上亮下暗与细颗粒；通常只在框底楔形处露出。
		vec3 fill = fill_color.rgb * mix(1.16, 0.70, vertical);
		fill *= 1.0 + (grain - 0.5) * noise_amt;
		c = vec4(fill, fill_color.a);
	}
	COLOR = c * COLOR;                         // 乘 modulate（阵亡压灰/选中提亮走它）
}
