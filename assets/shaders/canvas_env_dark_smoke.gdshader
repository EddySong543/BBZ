shader_type canvas_item;

// =============================================================
// canvas_env_dark_smoke.gdshader — 前/中景流动黑烟（Eddy 2026-07-10 新场景元素）
// 作者: Claude (Game Studios) ｜ 用途: scene1 战斗舞台氛围层（⚠非天上云/云海——那两个方向已否）
// 两种形态一份 shader（uniform 切换·mix 无动态分支）：
//   puff_isolation=0 连续带：波形上缘的流动黑烟（前景持续存在·整体呈波形）
//   puff_isolation=1 孤立片：x 向分格·一小片一小片独立缓漂的波形烟团（角色站立的房檐面）
// 局部 quad 非全屏；2 octave 值噪声零纹理采样；粗像素格 + 透明度色阶化贴像素风。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 低（纯数学·限高条带）。
// =============================================================

uniform vec4 smoke_color : source_color = vec4(0.028, 0.036, 0.06, 1.0);  // 近黑带一点夜蓝（融夜色不发灰）
uniform float alpha_max : hint_range(0.0, 1.0) = 0.3;    // 烟最实处透明度
uniform float flow_speed = 0.045;      // 流速（负值反向流）
uniform vec2 noise_scale = vec2(18.0, 2.6);   // 烟体噪声尺度 XY 分开（长条 rect 必须做宽高比校正·否则烟块被横向拉成脏方块）
uniform float wave_base : hint_range(0.0, 1.0) = 0.42;   // 连续带：上缘基准高度（rect UV）
uniform float wave_amp : hint_range(0.0, 0.6) = 0.2;     // 连续带：上缘波形幅度
uniform float wave_freq = 3.0;         // 连续带：上缘低频波数（整条 rect 内周期数）
uniform float edge_soft : hint_range(0.02, 0.6) = 0.32;  // 上缘→烟体的过渡宽度
uniform float puff_isolation : hint_range(0.0, 1.0) = 0.0;  // 0=连续带 1=孤立片
uniform float puff_cells = 7.0;        // 孤立片：x 向格数（每格至多一片）
uniform float puff_keep : hint_range(0.0, 1.0) = 0.62;   // 孤立片：出片比例（其余格留空=孤立感）
uniform float alpha_steps = 4.0;       // 透明度色阶化级数（手绘烟感·防平滑渐变出戏）
uniform vec2 pixel_grid = vec2(680.0, 90.0);   // 粗像素格（按实例 rect 尺寸/3px 配）
uniform vec4 rim_color : source_color = vec4(0.62, 0.78, 1.0, 1.0);  // 月光缘色（冷蓝·同场景 rim 语言）
uniform float rim_alpha : hint_range(0.0, 0.6) = 0.16;  // 月光缘强度——暗底上烟的可读性全靠这条薄边（云海纪律：只一条亮缘）


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


// 值噪声 + 两倍频 fbm：烟体的翻卷纹理（零纹理采样）
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


float fbm(vec2 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.3 + vec2(7.7, 1.3)) * 0.35;
}


void fragment() {
	vec2 uv = floor(UV * pixel_grid) / pixel_grid;   // 粗像素格量化
	float t = TIME * flow_speed;
	// 烟体：横向主流 + 纵向微对流 → 翻卷感；smoothstep 重映射拉开对比（防成均匀薄雾·暗底上要能读出团块）
	float body = smoothstep(0.22, 0.78,
			fbm(vec2(uv.x * noise_scale.x - t * 3.0, uv.y * noise_scale.y + t * 0.8)));
	// 连续带：波形上缘 = 低频 sin + 高频噪声起伏·越往下越实（噪声项跟随 x 尺度防被拉平）
	float top = wave_base + sin(uv.x * wave_freq * 6.2832 + t * 2.5) * wave_amp * 0.4
			+ (fbm(vec2(uv.x * noise_scale.x * 0.35 + t * 1.6, 3.3)) - 0.5) * wave_amp;
	float band = smoothstep(top, top + edge_soft, uv.y);
	// 孤立片：x 分格·部分格留空·片内横椭圆衰减（扁片=波形云）+ 每片独立相位缓漂
	float cx = uv.x * puff_cells;
	float cell = floor(cx);
	float keep = step(hash(vec2(cell, 5.13)), puff_keep);
	vec2 pc = vec2(fract(cx) - 0.5 + sin(t * 4.0 + cell * 2.17) * 0.07,
			(uv.y - 0.5 - (hash(vec2(cell, 9.7)) - 0.5) * 0.3) * 0.9);
	// 边界距离叠噪声扰动 → 烟片轮廓成波形碎缘（防干净椭圆读作"泡泡"）
	float pshape = length(pc) + (body - 0.5) * 0.24;
	float puff = keep * (1.0 - smoothstep(0.1, 0.38 + hash(vec2(cell, 2.2)) * 0.12, pshape));
	float cover = mix(band, puff, puff_isolation);
	// 暗体 + 形体薄边一线月光缘（cover 低值区=烟形边缘）：暗底之夜烟的形全靠这条缘读出
	float fill_a = cover * body * alpha_max;
	float rim_w = (smoothstep(0.03, 0.16, cover) - smoothstep(0.16, 0.5, cover)) * body * rim_alpha;
	float a = max(fill_a, rim_w) * smoke_color.a;
	vec3 rgb = mix(smoke_color.rgb, rim_color.rgb, clamp(rim_w / max(a, 1e-4), 0.0, 1.0));
	a = floor(a * alpha_steps + 0.5) / alpha_steps;   // 色阶化（像素风的烟不做平滑渐变）
	COLOR = vec4(rgb, a);
}
