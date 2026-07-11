shader_type canvas_item;
render_mode blend_add;

// =============================================================
// canvas_env_aurora.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 夜空天光带/极光（奇幻感试装 B·2026-07-11 Eddy 点单）
//   一条极淡的青蓝→紫天光缎带横过上部夜空，中段没入巨月之后（月节点在其上层遮挡）、
//   两侧探出 → 读作"绕月而行的异象天光"。给现实夜景补一件"现实中不存在的东西"。
//   ⚠ 反"脏"与性能纪律：局部 quad·加法混合低强度封顶·缎带=双频 sin 波中线+上羽下实
//     不对称羽化·帘状竖纹=sin 疏密·grain 像素粗格贴像素风。
//   ⚠ 防矩形切边铁律：上下节点缘保底淡出（edge_v）·缎带波幅+羽化不得越出节点矩形。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 每像素 5 次 sin → 极低。
// 无变体/关键字。坐标系=节点局部 px（size_px 须与 .tscn 节点矩形尺寸一致）。
// =============================================================

uniform vec2 size_px = vec2(2016.0, 400.0);            // 节点矩形尺寸(px·UV→局部px 换算)
uniform float base_y = 170.0;                          // 缎带中线基准高(局部y px)
uniform float amp1 = 46.0;                             // 主波幅(px·低频起伏)
uniform float amp2 = 22.0;                             // 次波幅(px·高频细颤)
uniform float freq1 = 0.0021;                          // 主波频率(1/px)
uniform float freq2 = 0.0057;                          // 次波频率(1/px)
uniform float thickness = 55.0;                        // 缎带基础半厚(px)
uniform float soft_up : hint_range(0.5, 4.0) = 2.2;   // 上缘羽化倍数(极光向上发丝感)
uniform float soft_down : hint_range(0.2, 2.0) = 0.8; // 下缘羽化倍数(下实)
uniform vec4 color_a : source_color = vec4(0.35, 0.9, 0.75, 1.0);   // 青绿端
uniform vec4 color_b : source_color = vec4(0.55, 0.4, 0.95, 1.0);   // 紫端
uniform float intensity : hint_range(0.0, 0.5) = 0.16; // 最浓强度（加法混合·反脏封顶）
uniform float streak_scale = 0.045;                    // 帘状竖纹频率(1/px)
uniform float streak_strength : hint_range(0.0, 1.0) = 0.35;  // 竖纹疏密对比
uniform float drift_speed : hint_range(0.0, 0.1) = 0.012;     // 整体漂移速度（极慢）
uniform float grain_px : hint_range(1.0, 8.0) = 3.0;   // 像素粗格(px)


void fragment() {
	// 采样点吸附 grain 网格 → 缎带边缘呈像素阶梯（非平滑矢量感）
	vec2 p = floor(UV * size_px / grain_px) * grain_px;
	float ph = TIME * drift_speed * 6.2832;
	// 缎带中线：双频正弦起伏 + 极慢漂移
	float cy = base_y + amp1 * sin(p.x * freq1 + ph) + amp2 * sin(p.x * freq2 - ph * 1.7);
	float d = p.y - cy;
	// 不对称羽化：上缘拉长（极光发丝向上）·下缘收实
	float half_t = thickness * (d < 0.0 ? soft_up : soft_down);
	float band = 1.0 - smoothstep(0.0, half_t, abs(d));
	band *= band;   // 平方收窄亮芯 → 中线亮、缘部极淡
	// 帘状竖纹：sin 疏密 + 相位随位置缓摆 → 极光垂帘质感
	float streak = 1.0 - streak_strength * (0.5 + 0.5 * sin(p.x * streak_scale + sin(p.x * 0.013 + ph) * 2.0));
	// 色相沿带渐变：青绿 ↔ 紫 极慢滑动
	float t = 0.5 + 0.5 * sin(p.x * 0.0016 - ph * 0.6);
	vec3 col = mix(color_a.rgb, color_b.rgb, t);
	// 节点上下缘保底淡出（防矩形切边铁律）
	float edge_v = smoothstep(0.0, 40.0, p.y) * (1.0 - smoothstep(size_px.y - 60.0, size_px.y, p.y));
	COLOR = vec4(col, band * streak * intensity * edge_v);
}
