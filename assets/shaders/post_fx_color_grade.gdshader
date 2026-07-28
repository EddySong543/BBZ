shader_type canvas_item;

// =============================================================
// post_fx_color_grade.gdshader  (v2: + 光学畸变(鱼眼) + 边缘模糊)
// 作者: Claude (Game Studios) ｜ 用途: scene1 战斗世界全屏后处理（PostFX 层，UI 之下）
//   桶形畸变(中央外凸鱼眼) + 边缘径向模糊(强化中心聚焦) + 色彩分级 + split-tone
//   + 暗角 + 颗粒。把世界统一进靛蓝午夜；UI 在更上层绘制，不受影响（隔离）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 5 次屏幕采样(边缘模糊)、全屏 → 低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，配合 BackBufferCopy 读 SCREEN_TEXTURE）。
// =============================================================

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;  // nearest：像素硬边不被重采样糊(像素风·桶形畸变/边缘模糊仍靠多 tap 采样实现)；repeat_disable：鱼眼外推/shake 时夹到边缘，不露灰块

group_uniforms lens;  // 光学畸变 + 边缘模糊（聚焦中心）
uniform float barrel_amount : hint_range(-0.3, 0.3) = 0.06;     // 桶形畸变(正=中央外凸鱼眼，负=内凹)
uniform float barrel_edge_margin : hint_range(0.02, 0.4) = 0.15; // 畸变在四边这么宽内渐隐到0 → 不往屏外采样(消除震动时四角夹边小黑块)
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

group_uniforms impact_frame;  // 冲击帧（动画 impact frame·终结命中拍·battle_screen._bw_flash 硬切驱动）
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;   // 0=关闭（mix 归零·零影响）1=全开
uniform float impact_invert : hint_range(0.0, 1.0) = 0.0;     // 0=正片 1=负片（黑白互换·闪烁张力）
uniform vec2  impact_center = vec2(0.5, 0.55);                // 炸开中心（SCREEN_UV·受击者位置）
uniform float impact_burst_radius : hint_range(0.05, 0.8) = 0.26;  // 炸开白域基础半径（UV·纵向尺度）
uniform float impact_jag : hint_range(0.0, 0.3) = 0.11;       // 毛边锯齿幅度（角度噪声抖动半径·炸开撕裂感）
uniform float impact_jag_freq = 7.0;                          // 锯齿角频率（越大齿越碎）
uniform float impact_th_out : hint_range(0.0, 1.0) = 0.52;    // 炸开区外二值化阈（高=大片墨黑只留高光）
uniform float impact_th_in : hint_range(0.0, 1.0) = 0.13;     // 炸开区内二值化阈（低=大片纸白·角色成黑剪影）
uniform float impact_white : hint_range(0.5, 1.0) = 0.86;     // 纸白亮度上限（<1 压刺眼·Eddy 2026-07-10"闪到我了"调）
uniform float impact_px = 3.0;                                // 毛边像素粗格（贴全局像素风）
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

	// 0) 桶形畸变：按到中心距离向外推采样坐标 → 中央外凸。
	//    ★ 推移按"离每条边的距离"在四边渐隐到 0(barrel_edge_margin) → duv 不会被推出屏外，
	//    彻底消除四角"夹边涂抹"(震动时表现为会动的小黑块)；clamp 仅作最终保险。
	vec2 edge_t = smoothstep(vec2(0.0), vec2(barrel_edge_margin), SCREEN_UV)
		* smoothstep(vec2(0.0), vec2(barrel_edge_margin), vec2(1.0) - SCREEN_UV);
	vec2 duv = clamp(SCREEN_UV + cen * r2 * barrel_amount * edge_t, vec2(0.0), vec2(1.0));

	// 1) 边缘径向模糊：离中心越远越糊（中心保持清晰，聚焦）
	vec3 col;
	if (edge_blur_amount <= 0.0001) {
		// Uniform-coherent fast path: Scene2 avoids four identical full-screen reads.
		col = texture(screen_tex, duv).rgb;
	} else {
		float bw = smoothstep(edge_blur_start, 1.0, dist) * edge_blur_amount;
		vec2 bpx = SCREEN_PIXEL_SIZE * bw * 2.5;
		// 把模糊采样中心收进屏内 bpx → 上下左右 4 个偏移采样都不越界(不再夹到单个暗边缘像素 → 消除残留小黑块)
		vec2 sdv = clamp(duv, bpx, vec2(1.0) - bpx);
		col = texture(screen_tex, sdv).rgb * 0.4;
		col += texture(screen_tex, sdv + vec2(bpx.x, 0.0)).rgb * 0.15;
		col += texture(screen_tex, sdv - vec2(bpx.x, 0.0)).rgb * 0.15;
		col += texture(screen_tex, sdv + vec2(0.0, bpx.y)).rgb * 0.15;
		col += texture(screen_tex, sdv - vec2(0.0, bpx.y)).rgb * 0.15;
	}

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

	// 7) 冲击帧（impact frame·Eddy 2026-07-10 定 A/A/A：二值化墨黑纸白 + 受击点锯齿炸开 + 正负反转）
	//    结构：受击点周围一团锯齿毛边"白炸开"（区内低阈→大片纸白·角色成黑剪影），
	//    区外高阈→大片墨黑只留高光 → 黑场中央一记白炸，剪影分明。无动态分支（step/mix）。
	if (impact_strength > 0.0001) {
		// Uniform-coherent fast path skips this block during normal battle rendering.
		vec2 iuv = floor(SCREEN_UV / (SCREEN_PIXEL_SIZE * impact_px)) * SCREEN_PIXEL_SIZE * impact_px;  // 毛边走粗像素格
		vec2 idv = iuv - impact_center;
		idv.x *= SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 1e-6);   // 宽高比校正 → 等距圆
		float iang = atan(idv.y, idv.x);
		// 毛边：粗齿 + 碎齿两层角度噪声抖动炸开半径 → 手绘撕裂边
		float jag = hash(vec2(floor(iang * impact_jag_freq), 7.31)) * 0.7
				+ hash(vec2(floor(iang * impact_jag_freq * 3.0), 3.17)) * 0.3;
		float irad = impact_burst_radius + (jag - 0.5) * 2.0 * impact_jag;
		float burst = 1.0 - step(irad, length(idv));                     // 1=炸开区内
		float ilum = dot(col, vec3(0.299, 0.587, 0.114));
		float ibw = step(mix(impact_th_out, impact_th_in, burst), ilum); // 区内低阈纸白 / 区外高阈墨黑
		ibw = mix(ibw, 1.0 - ibw, impact_invert);                        // 负片一闪（PV 张力）
		col = mix(col, vec3(ibw * impact_white), impact_strength);       // 纸白压亮度上限（不刺眼·黑不受影响）
	}

	COLOR = vec4(col, 1.0);
}
