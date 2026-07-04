shader_type canvas_item;

// =============================================================
// canvas_ui_paper.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 图鉴 v5「实体典籍」面材质感（书页/封皮/图标卡/书签/返回芯片）。
//   像素纸/皮质感：粗格噪点颗粒 + 连续内渐变（中心亮/边缘沉）+ 色阶量化。
//   治"纯色图层没质感"（Eddy 2026-07-04 F6）。遵循「像素粗格法」铁律：整格纯色、无上采样、无平滑。
// 旋钮：grain_amt 颗粒强度 / shade_amt 边缘沉降 / cells_x 颗粒粗细 / levels 色阶。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 大 quad、1 次 hash → 极低。
// 渲染管线: Godot 4.x Forward+（2D canvas_item）。
// =============================================================

group_uniforms palette;
uniform vec4 base_color : source_color = vec4(0.94, 0.89, 0.72, 1.0); // 面色（中心）
uniform vec4 deep_color : source_color = vec4(0.82, 0.76, 0.58, 1.0); // 边缘沉降色
group_uniforms;

group_uniforms shape;
uniform float cells_x : hint_range(4.0, 500.0) = 180.0;   // 横向粗格数（颗粒粒径 = 宽/cells_x）
uniform float aspect : hint_range(0.01, 60.0) = 1.0;      // 宽/高（非方形必传·否则颗粒被拉扁）
group_uniforms;

group_uniforms craft;
uniform float grain_amt : hint_range(0.0, 0.2) = 0.035;   // 颗粒振幅（0=关）
uniform float shade_amt : hint_range(0.0, 1.0) = 0.55;    // 边缘沉降强度 0..1（0=全平）
uniform float shade_start : hint_range(0.0, 1.0) = 0.55;  // 沉降起点（0 中心..1 边缘）
uniform float levels : hint_range(8.0, 128.0) = 40.0;     // 色阶量化档数（防渐变糊成滑面）
group_uniforms;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / max(aspect, 0.0001));
	vec2 cell = floor(UV * grid);
	vec2 cuv = (cell + 0.5) / grid;   // 格心采样 → 整格纯色

	// 连续内渐变：中心亮、边缘沉（矩形距离场）
	vec2 d = abs(cuv - 0.5) * 2.0;
	float edge = max(d.x, d.y);
	float shade = smoothstep(shade_start, 1.0, edge) * shade_amt;
	vec3 col = mix(base_color.rgb, deep_color.rgb, shade);

	// 粗格颗粒（每格一枚·纸纤维/皮理感）
	col += (hash21(cell) - 0.5) * 2.0 * grain_amt;

	// 色阶量化（像素工艺·防滑面）
	col = floor(col * levels + 0.5) / levels;

	COLOR = vec4(col, base_color.a * COLOR.a);
}
