shader_type canvas_item;

// Banner画芯只在此裁切为像素圆角轮廓；清晰可见的按钮外框由独立FrameOverlay绘制。
// 图片和框因此是“内嵌画芯 + 上层边框”，而不是把边框颜色融合进图片。
uniform float pixel_grid : hint_range(8.0, 64.0) = 38.0;
uniform float corner : hint_range(0.0, 0.5) = 0.08;
uniform float aspect : hint_range(0.25, 8.0) = 3.0;

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 grid = vec2(pixel_grid * aspect, pixel_grid);
	vec2 cell = floor(UV * grid);
	vec2 puv = (cell + 0.5) / grid;
	float upx = 1.0 / pixel_grid;
	vec2 ap = vec2((puv.x - 0.5) * aspect, puv.y - 0.5);
	vec2 bounds = vec2(0.5 * aspect - upx, 0.5 - upx);
	float distance_to_edge = rbox(ap, bounds, corner);
	float inside = step(distance_to_edge, 0.0);
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(source.rgb, source.a * inside) * COLOR;
}
