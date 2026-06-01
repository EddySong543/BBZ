shader_type canvas_item;

// =============================================================
// canvas_env_horizon_haze.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 地平线雾霾带（大气透视，全屏 alpha 层）
//   在屋顶后方、天空底部叠一层半透明夜雾：地平线处最浓、往天顶渐隐，
//   噪声调制让上边界起伏并缓慢横向流动 → 远处"消失在雾里"，画面获得纵深与空气感。
//   放在屋顶之前 → 下半被主屋顶遮挡，只露屋脊线上方的雾霾。非雾区 alpha=0 透出夜空。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、2-octave 噪声 → 低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动流动）。
// =============================================================

group_uniforms shape;
uniform vec4 haze_color : source_color = vec4(0.16, 0.22, 0.34, 1.0); // 夜雾色(散射光,偏亮蓝灰)
uniform float haze_top : hint_range(0.0, 1.0) = 0.42;       // 雾上边界(UV.y)：往上完全透明
uniform float haze_bottom : hint_range(0.0, 1.0) = 0.66;    // 雾下边界(最浓)：以下被屋顶遮挡
uniform float haze_intensity : hint_range(0.0, 1.0) = 0.5;  // 最大浓度(alpha 上限)
group_uniforms;

group_uniforms texture_feel;
uniform float noise_scale : hint_range(0.5, 8.0) = 3.0;     // 噪声起伏尺度
uniform float noise_amount : hint_range(0.0, 1.0) = 0.55;   // 噪声对浓度的起伏深度
uniform float edge_wobble : hint_range(0.0, 0.2) = 0.06;    // 上边界被噪声扰动幅度(像雾不像直线)
uniform float flow_speed : hint_range(0.0, 0.2) = 0.02;     // 横向流动速度
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	return noise(p) * 0.65 + noise(p * 2.1 + 7.3) * 0.35;
}

void fragment() {
	float y = UV.y;
	// 流动噪声场
	vec2 np = vec2(UV.x * noise_scale + TIME * flow_speed, UV.y * noise_scale * 0.5);
	float n = fbm(np);
	// 噪声扰动上边界 → 雾顶起伏不规则（不是死板直线）
	float top = haze_top + (n - 0.5) * 2.0 * edge_wobble;
	// 从上(透明)到下(浓)的渐变
	float band = smoothstep(top, haze_bottom, y);
	// 噪声调制浓度（让雾团块状、不均匀）
	float fog = band * mix(1.0 - noise_amount, 1.0, n) * haze_intensity;
	COLOR = vec4(haze_color.rgb, clamp(fog, 0.0, 1.0));
}
