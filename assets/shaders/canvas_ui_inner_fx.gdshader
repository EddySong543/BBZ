shader_type canvas_item;

// =============================================================
// canvas_ui_inner_fx.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 头像框内层 FX「内阴影暗角(B) + 极淡扫描线(D)」——纯暗色半透明叠层。
//   叠在头像之上、边框之下；不采样头像，只输出"暗色 + alpha" → 压暗边缘(把人物嵌进框)、加复古像素扫描线。
//   vignette_* 控暗角；scan_* 控扫描线(很淡，否则伤简约)。颜色为暗色(略冷)。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 极低。渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

group_uniforms vignette;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;  // 边缘压暗强度
uniform float vignette_edge : hint_range(0.0, 0.5) = 0.32;     // 暗角范围(0=贴边, 越大越往中心)
group_uniforms;

group_uniforms scanline;
uniform float scan_strength : hint_range(0.0, 0.5) = 0.08;     // 扫描线深度(很淡)
uniform float scan_lines : hint_range(8.0, 96.0) = 48.0;       // 扫描线条数
group_uniforms;

group_uniforms palette;
uniform vec4 shade_color : source_color = vec4(0.0, 0.0, 0.02, 1.0);  // 暗色(略带冷)
group_uniforms;

group_uniforms shape;
uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;  // 圆角(与边框一致 → 内阴影不越出圆角)
uniform float pixel_grid : hint_range(8.0, 48.0) = 24.0;   // 圆角像素台阶格数
group_uniforms;

// 像素台阶圆角遮罩：角落圆弧外 → 0(切掉)。
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
	vec2 uv = UV;
	// B 内阴影：到最近边的距离 → 越靠边越暗
	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float vig = (1.0 - smoothstep(0.0, vignette_edge, d)) * vignette_strength;
	// D 扫描线：每隔一行压暗(像素带)
	float scan = step(0.5, fract(uv.y * scan_lines)) * scan_strength;
	float a = clamp(vig + scan, 0.0, 1.0);
	a *= corner_round_alpha(uv, corner_radius, pixel_grid);  // 圆角
	COLOR = vec4(shade_color.rgb, a) * COLOR;  // 乘 incoming COLOR(携带 modulate) → 跟随父节点变暗(需节点 color=白)
}
