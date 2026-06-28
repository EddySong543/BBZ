shader_type canvas_item;

// =============================================================
// canvas_button_jelly.gdshader  (方案C v3 · 多层质感像素徽章 + 宽高比校正)
// 作者: Claude (Game Studios) ｜ 用途: 战斗动作按钮底框 / 技能展示格底框
//   解决「两色像简笔画」：圆角方 + 垂直渐变底 + 像素噪点纹理 + 磨损做旧 +
//   内层亮高光边(立体) + 外层暗轮廓。多层明暗 → 成熟 UI 质感；颜色仍交还图标。
//   v3: 新增 aspect(宽/高) → 长矩形上像素格保持方形、圆角/边框四周等宽，
//       不再被横向拉伸成「拖糊」。aspect 默认 1.0 → 近方形按钮/头像框零影响。
//   挂控件内填满+show_behind_parent 的 ColorRect；气泡复用同材质自动一致。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 小 quad、少量 hash → 极低。
// =============================================================

group_uniforms palette;
uniform vec4 fill_top : source_color = vec4(0.25, 0.28, 0.38, 1.0);    // 底渐变·上(亮)
uniform vec4 fill_bottom : source_color = vec4(0.13, 0.15, 0.23, 1.0); // 底渐变·下(暗)
uniform vec4 edge_inner : source_color = vec4(0.58, 0.52, 0.36, 1.0);  // 内高光边(暖金,立体)
uniform vec4 edge_outer : source_color = vec4(0.05, 0.06, 0.10, 1.0);  // 外轮廓(暗)
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.92;
group_uniforms;

group_uniforms shape;
uniform float pixel_grid : hint_range(8.0, 64.0) = 38.0;    // 像素网格分辨率(以高度计)
uniform float corner : hint_range(0.0, 0.5) = 0.22;   // 圆角(0方 0.5圆，以高度计)
uniform float edge_px : hint_range(0.0, 4.0) = 2.0;   // 每层边宽(像素格)
uniform float aspect : hint_range(0.25, 8.0) = 1.0;   // 矩形宽/高；>1=横向补格→像素方形、边框等宽
group_uniforms;

group_uniforms texture_feel;
uniform float noise_amt : hint_range(0.0, 0.3) = 0.05; // 内部噪点纹理强度
uniform float wear : hint_range(0.0, 0.6) = 0.22;      // 边缘磨损做旧强度(随机点黑·会让内圈呈离散灰点)
// 连续深色内描边：开 → 亮色边内侧画一条「连续不断的深色描边」(参考 ref12 实线深边)，
//   并取消随机磨损点(否则那圈深边会变成一个个分开的灰点·离散感)。关(默认) → 沿用原磨损做旧。
uniform bool solid_rim = false;
uniform float rim_px : hint_range(0.0, 4.0) = 1.5;     // 内描边宽度(像素格)
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// 横向按 aspect 增加格数 → 每个像素格保持方形(长矩形不再横向拉糊)。
	vec2 grid = vec2(pixel_grid * aspect, pixel_grid);
	vec2 cell = floor(UV * grid);
	vec2 puv = (cell + 0.5) / grid;
	float upx = 1.0 / pixel_grid;                       // 一格 = 高度的 1/pixel_grid(统一单位)

	// 在「高度归一」空间求圆角矩形 SDF：x 乘 aspect → 圆角/边宽四周等宽、不随宽度变形。
	vec2 ap = vec2((puv.x - 0.5) * aspect, puv.y - 0.5);
	vec2 b = vec2(0.5 * aspect - upx, 0.5 - upx);
	float d = rbox(ap, b, corner);
	float inside = step(d, 0.0);
	float ew = edge_px * upx;
	float outer = step(-ew, d) * inside;                              // 最外暗轮廓
	float inner = step(-2.0 * ew, d) * (1.0 - step(-ew, d)) * inside; // 次外亮高光边
	// 连续深色内描边：亮边内侧一条等宽暗带(实线·不随机·solid_rim 时启用)
	float rw = rim_px * upx;
	float rim = solid_rim
		? step(-(2.0 * ew + rw), d) * (1.0 - step(-2.0 * ew, d)) * inside
		: 0.0;

	// 底：垂直渐变(上亮下暗) + 内部像素噪点
	vec3 col = mix(fill_top.rgb, fill_bottom.rgb, clamp(puv.y + 0.5, 0.0, 1.0));
	col *= 1.0 + (hash(cell) - 0.5) * noise_amt;

	// 磨损做旧：靠边缘的像素格随机压暗。solid_rim 时关掉(否则内圈呈一个个离散灰点)。
	float near = step(-3.0 * ew, d) * inside;
	float wear_dots = solid_rim ? 0.0 : step(0.72, hash(cell + 5.1));
	col *= 1.0 - wear * near * wear_dots;

	// 多层边：内亮高光(立体凸起) + 连续深色内描边 + 外暗轮廓
	col = mix(col, edge_inner.rgb, inner);
	col = mix(col, edge_outer.rgb, rim);
	col = mix(col, edge_outer.rgb, outer);

	float a = mix(fill_alpha, 1.0, max(max(inner, outer), rim));
	COLOR = vec4(col, a * inside) * COLOR;
}
