shader_type canvas_item;

// =============================================================
// canvas_env_clouds.gdshader  (v2: 旋转 fbm + 域扭曲，消除 value-noise 方格)
// 作者: Claude (Game Studios) ｜ 用途: scene1 月夜薄云（全屏 alpha 层，遮月用）
//   ★ v2 修复"一格格透明长方形"：value noise 低频时格点轴对齐 → 露方格。
//     解法 = fbm 每 octave 旋转坐标(打破轴对齐) + 5 octave + 轻度域扭曲(打散残留网格)。
//   fbm 噪声 + 横向拉伸(层云感) + 缓慢横向飘动；上部天空浓、往下渐隐。画在月之上 → 遮月。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、~6 次噪声 → 低-中。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动飘动）。
// =============================================================

group_uniforms look;
uniform vec4 cloud_color : source_color = vec4(0.30, 0.36, 0.50, 1.0); // 月夜薄云(蓝灰偏亮)
uniform float coverage : hint_range(0.0, 1.0) = 0.52;     // 云量阈值(高=云更少更薄)
uniform float softness : hint_range(0.01, 0.6) = 0.28;    // 云边缘软度(高=更朦胧)
uniform float opacity : hint_range(0.0, 1.0) = 0.6;       // 整体不透明上限
group_uniforms;

group_uniforms shape;
uniform vec2 cloud_scale = vec2(2.0, 4.5);                 // 噪声尺度(x<y → 横向拉伸的层云)
uniform float drift_speed : hint_range(0.0, 0.1) = 0.012;  // 飘动速度
uniform float warp_amount : hint_range(0.0, 1.5) = 0.6;    // 域扭曲强度(打散网格；过大会过扭)
uniform float top_bias : hint_range(0.0, 1.0) = 0.55;      // 云集中带(此 UV.y 以上浓)
uniform float fade_span : hint_range(0.05, 0.6) = 0.3;     // 向下渐隐跨度
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
// 每 octave 旋转 ~37° + 缩放 + 偏移 → 打破 value noise 的方形网格轴对齐
const mat2 ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p = ROT * p * 2.02 + vec2(11.3, 7.9);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * cloud_scale + vec2(TIME * drift_speed, 0.0);
	// 轻度域扭曲：用低频噪声扰动采样坐标，进一步打散残留网格规则性
	vec2 warp = vec2(noise(uv * 0.5 + 13.1), noise(uv * 0.5 + 41.7)) - 0.5;
	float n = fbm(uv + warp * warp_amount);
	// 阈值 + 软边 → 云团形状
	float cloud = smoothstep(coverage, coverage + softness, n);
	// 上部浓、往下渐隐（云在天空不在地面）
	float vmask = smoothstep(top_bias, top_bias - fade_span, UV.y);
	float a = cloud * vmask * opacity;
	COLOR = vec4(cloud_color.rgb, clamp(a, 0.0, 1.0));
}
