shader_type canvas_item;

// =============================================================
// post_fx_color_grade.gdshader  (v2: + 光学畸变(鱼眼) + 边缘模糊)
// 作者: Claude (Game Studios) ｜ 用途: scene1 战斗世界全屏后处理（PostFX 层，UI 之下）
//   桶形畸变(中央外凸鱼眼) + 边缘径向模糊(强化中心聚焦) + 色彩分级 + split-tone
//   + 暗角 + 颗粒。把世界统一进靛蓝午夜；UI 在更上层绘制，不受影响（隔离）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 5 次屏幕采样(边缘模糊)、全屏 → 低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，配合 BackBufferCopy 读 SCREEN_TEXTURE）。
// =============================================================

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;  // linear：边缘模糊；repeat_disable：鱼眼外推/shake 时夹到边缘，不露灰块

group_uniforms lens;  // 光学畸变 + 边缘模糊（聚焦中心）
uniform float barrel_amount : hint_range(-0.3, 0.3) = 0.06;     // 桶形畸变(正=中央外凸鱼眼，负=内凹)
uniform float edge_blur_amount : hint_range(0.0, 4.0) = 1.2;    // 边缘模糊强度
uniform float edge_blur_start : hint_range(0.0, 1.0) = 0.45;   // 模糊起始半径(此半径内保持清晰)
group_uniforms;

group_uniforms grade;
uniform float brightness : hint_range(0.5, 1.5) = 0.97;
uniform float contrast   : hint_range(0.5, 2.0) = 1.08;
uniform float saturation : hint_range(0.0, 2.0) = 0.88;
uniform vec3  tint_color : source_color = vec3(0.85, 0.92, 1.10);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.40;
group_uniforms;

group_uniforms split_tone;
uniform vec3  shadow_tint    : source_color = vec3(0.88, 0.94, 1.08);
uniform vec3  highlight_tint : source_color = vec3(1.06, 1.00, 0.90);
uniform float split_strength : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

group_uniforms vignette;
uniform vec3  vignette_color : source_color = vec3(0.012, 0.020, 0.047);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.40;
uniform float vignette_radius   : hint_range(0.3, 1.2) = 0.90;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.55;
group_uniforms;

group_uniforms grain;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.02;
uniform float grain_scale  : hint_range(0.5, 4.0) = 1.6;
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cen = SCREEN_UV - 0.5;
	float r2 = dot(cen, cen);
	float dist = length(cen) * 1.4142;   // 0 中心 → ~1 画角

	// 0) 桶形畸变：按到中心距离向外推采样坐标 → 中央外凸（clamp 防越界灰块）
	vec2 duv = clamp(SCREEN_UV + cen * r2 * barrel_amount, vec2(0.0), vec2(1.0));

	// 1) 边缘径向模糊：离中心越远越糊（中心保持清晰，聚焦）
	float bw = smoothstep(edge_blur_start, 1.0, dist) * edge_blur_amount;
	vec2 bpx = SCREEN_PIXEL_SIZE * bw * 2.5;
	vec3 col = texture(screen_tex, duv).rgb * 0.4;
	col += texture(screen_tex, duv + vec2(bpx.x, 0.0)).rgb * 0.15;
	col += texture(screen_tex, duv - vec2(bpx.x, 0.0)).rgb * 0.15;
	col += texture(screen_tex, duv + vec2(0.0, bpx.y)).rgb * 0.15;
	col += texture(screen_tex, duv - vec2(0.0, bpx.y)).rgb * 0.15;

	// 2) 亮度 → 对比(绕 0.5) → 饱和(绕 luma)
	col *= brightness;
	col = (col - 0.5) * contrast + 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// 3) 夜色染色
	col = mix(col, col * tint_color, tint_strength);

	// 4) 暗部/高光分离染色
	vec3 toned = col * mix(shadow_tint, highlight_tint, clamp(luma, 0.0, 1.0));
	col = mix(col, toned, split_strength);

	// 5) 暗角
	float vig = smoothstep(vignette_radius, vignette_radius - vignette_softness, dist);
	col = mix(mix(vignette_color, col, vig), col, 1.0 - vignette_strength);

	// 6) 统一低频颗粒
	float g = hash(SCREEN_UV / max(SCREEN_PIXEL_SIZE.y, 1e-5) * 0.01 * grain_scale) - 0.5;
	col += g * grain_amount;

	COLOR = vec4(col, 1.0);
}
