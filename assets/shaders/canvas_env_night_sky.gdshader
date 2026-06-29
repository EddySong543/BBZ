shader_type canvas_item;

// =============================================================
// canvas_env_night_sky.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 深夜夜空底（② 混搭半精细 + 缓慢天空呼吸）
// 月明星稀的深夜：深靛垂直渐变 + 极弱地平线辉光 + 极缓慢的大尺度明暗流动（云影掠过感，破"太静"）。
// ② 风：保持干净半精细（posterize 高、dither 仅防色带），统一像素颗粒留给最后整体滤镜。
// 目标平台: PC (Windows D3D12 / Forward+)。
// 复杂度预算: 全屏 1 pass、少量噪声、无纹理采样 —— 开销极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，用 TIME 驱动呼吸）。
// =============================================================

group_uniforms gradient;
uniform vec4 zenith_color : source_color = vec4(0.012, 0.020, 0.047, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.043, 0.063, 0.122, 1.0);
uniform float gradient_curve : hint_range(0.2, 3.0) = 1.5;
uniform float horizon_pos : hint_range(0.0, 1.2) = 1.0;
group_uniforms;

group_uniforms horizon_glow;
uniform vec4 glow_color : source_color = vec4(0.118, 0.196, 0.294, 1.0);
uniform float glow_width : hint_range(0.02, 0.6) = 0.28;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.18;
group_uniforms;

group_uniforms breath;
uniform float breath_amount : hint_range(0.0, 0.5) = 0.22;   // 呼吸明暗幅度（深夜暗天空需较大才看得出）
uniform float breath_speed : hint_range(0.0, 0.3) = 0.08;    // 横向流动速度
uniform float breath_scale : hint_range(0.3, 4.0) = 1.4;     // 云影起伏尺度
group_uniforms;

group_uniforms texture_feel;
uniform float dither_amount : hint_range(0.0, 0.06) = 0.012;
uniform int posterize_steps : hint_range(2, 256) = 64;  // 上限提到 256：暗渐变需更多级数压色带(banding)
uniform vec2 pixel_grid = vec2(1920.0, 1080.0);
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

void fragment() {
	float y = UV.y;

	float t = pow(clamp(y / max(horizon_pos, 0.001), 0.0, 1.0), gradient_curve);
	vec3 col = mix(zenith_color.rgb, horizon_color.rgb, t);

	float dy = (y - horizon_pos) / glow_width;
	col += glow_color.rgb * exp(-dy * dy) * glow_intensity;

	// 天空呼吸：低频噪声缓慢横向流动 → 大尺度明暗起伏（云影掠过的呼吸）
	float br = noise(vec2(UV.x * breath_scale + TIME * breath_speed, UV.y * breath_scale * 0.6));
	col *= 1.0 + (br - 0.5) * breath_amount;

	// 先抖后量化（dither 防色带，posterize 高 → 平滑半精细）
	// 用随机 hash 抖动（无 Bayer 4×4 方块 pattern → 不再有"无处不在的小正方形"）
	vec2 frag = UV * pixel_grid;
	float steps = float(posterize_steps);
	col += (hash(frag) - 0.5) * dither_amount;
	col = floor(col * steps + 0.5) / steps;

	COLOR = vec4(col, 1.0);
}
