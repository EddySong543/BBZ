shader_type canvas_item;

// =============================================================
// canvas_env_clouds.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 极淡薄云（FBM 噪声，缓慢横飘掠过月亮，全屏）
//   武侠水墨薄云：低对比、半透明、非发光勾边；垂直遮罩只留天空中上部；缓慢飘移破"太静"。
//   月明星稀 = 晴夜 → coverage 默认很低（只一两缕）。非云区 alpha=0 透出天空。
// 目标平台: PC (Windows D3D12 / Forward+)。
// 复杂度预算: 全屏 1 pass、4 阶 FBM（纯算术、无纹理）—— 开销低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，TIME 驱动飘移，alpha 混合）。
// =============================================================

group_uniforms shape;
uniform float cloud_scale : hint_range(0.5, 6.0) = 2.2;     // 云团尺度
uniform float coverage : hint_range(0.0, 1.0) = 0.34;       // 云量（低=稀薄，月明星稀）
uniform float softness : hint_range(0.02, 0.5) = 0.22;      // 云边软度
group_uniforms;

group_uniforms motion;
uniform float drift_speed : hint_range(0.0, 0.2) = 0.012;   // 横向飘速（极慢）
group_uniforms;

group_uniforms band;
uniform float band_top : hint_range(0.0, 1.0) = 0.04;       // 云带上界（屏幕 V）
uniform float band_bottom : hint_range(0.0, 1.0) = 0.55;    // 云带下界
uniform float band_soft : hint_range(0.01, 0.4) = 0.18;     // 云带边缘软度
group_uniforms;

group_uniforms look;
uniform vec4 cloud_color : source_color = vec4(0.32, 0.40, 0.55, 0.5);  // 淡灰蓝半透
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
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x * cloud_scale + TIME * drift_speed, uv.y * cloud_scale);
	float n = fbm(p);

	// 阈值化成稀疏云团（coverage 越高云越多）
	float cloud = smoothstep(1.0 - coverage, 1.0 - coverage + softness, n);

	// 垂直遮罩：只在天空中上部出现，向下淡出
	float vmask = smoothstep(band_top - band_soft, band_top + band_soft, uv.y)
		* (1.0 - smoothstep(band_bottom - band_soft, band_bottom + band_soft, uv.y));
	cloud *= vmask;

	COLOR = vec4(cloud_color.rgb, cloud * cloud_color.a);
}
