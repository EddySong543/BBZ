shader_type canvas_item;
render_mode blend_add;

// canvas_fx_speed_lines.gdshader
// 屏幕边缘速度线（动漫集中线·Eddy 2026-07-10·默认只在终结演出慢放期间出现）。
// 全屏 quad 但 strength=0 时整片透明零输出；放射状细线从画面边缘指向中心、
// 中心区留空不遮角色；低帧率抖动重排 = 手绘动画逐帧重绘感；粗像素格贴全局像素风。
// 复杂度：低（无纹理采样·纯数学·仅终结演出 ~2s 可见）。

uniform float strength : hint_range(0.0, 1.0) = 0.0;   // 0=完全关闭（平时）
uniform vec4 line_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform float inner_radius : hint_range(0.0, 0.8) = 0.34;   // 中心留空半径（UV 距离·不遮双雄）
uniform float edge_feather : hint_range(0.01, 0.4) = 0.12;  // 留空区→线区的过渡宽度
uniform float density = 72.0;         // 放射线根数
uniform float line_width : hint_range(0.02, 0.5) = 0.16;    // 单根线在扇形格内的宽占比
uniform float appear_ratio : hint_range(0.1, 1.0) = 0.55;   // 每帧亮线比例（其余根隐藏→抽帧闪烁）
uniform float jitter_fps = 11.0;      // 重排帧率（低帧=动漫重绘抖动）
uniform vec2 pixel_grid = vec2(640.0, 360.0);   // 粗像素格（1920/3=640 → 3px 格）
uniform float aspect = 1.7778;        // 画面宽高比（1920/1080）


float hash11(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}


void fragment() {
	if (strength <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// 粗像素格量化 → 线条边缘呈阶梯像素而非平滑斜线
		vec2 uvq = floor(UV * pixel_grid) / pixel_grid;
		vec2 d = uvq - vec2(0.5);
		d.x *= aspect;
		float r = length(d);
		float ang = atan(d.y, d.x) / (2.0 * PI) + 0.5;   // 0..1 圆周
		float t = floor(TIME * jitter_fps);              // 抽帧时基
		float spoke = ang * density;
		float id = floor(spoke);
		float h_on = hash11(id + t * 131.7);             // 本帧该根亮不亮
		float h_len = hash11(id * 3.7 + t * 57.3);       // 本帧该根起点抖动（长短不齐）
		float s = fract(spoke);
		float line = step(abs(s - 0.5), line_width * 0.5) * step(h_on, appear_ratio);
		float start_r = inner_radius + h_len * 0.14;
		float mask = smoothstep(start_r, start_r + edge_feather, r);
		float a = strength * line * mask * line_color.a;
		COLOR = vec4(line_color.rgb, a);
	}
}
