shader_type canvas_item;

// =============================================================
// canvas_env_eclipse.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 加时赛紫日食「烛阴之眼」（v2·2026-07-11 Eddy 四条微调）
//   两相位程序化日食（final_mix 驱动）+ 两段蚕食（Eddy 五改定形）：
//   裂缝段=黑色裂纹自月缘向心伸展（crack 0→1·条条长短不一/沿径扭动·⛔直线放射条）；
//   吞噬段=黑暗自月缘四周向心咔嚓吞尽（eat 0→1·前沿=多谐波不规则指状·
//   ⛔正圆收缩环——会复发 LED 感·Eddy 2026-07-11 三改点名），均只在月面掩模内显形；
//   成相期(final_mix=1)=近黑暗盘+盘缘亮环+外冕柔光。
//   反 LED 圈（Eddy 批"太平滑像灯圈"）：盘缘半径随角度低频起伏（轻微不圆）+
//   环亮度/环宽角向双频流转（光斑缓缓游走）——幅度压低=有机光，⛔锯齿冕芒/放射条（音条感已否）。
//   ⚠ 反方块纪律：grain 仅 2px 细粒吸附·所有衰减平滑函数。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 每像素 1 次 atan + 1 次 exp + 数次 sin → 低。
// 无变体/关键字。坐标系=UV（size_px 仅 grain 换算·须与节点矩形一致）。
// =============================================================

uniform vec2 size_px = vec2(660.0, 660.0);              // 节点矩形尺寸(px·grain 换算用)
uniform float crack : hint_range(0.0, 1.0) = 0.0;       // 裂缝段进度(0=无·1=裂纹全伸·由代码 tween)
uniform float eat : hint_range(0.0, 1.0) = 0.0;         // 吞噬段进度(0=完月·1=全噬·由代码 tween)
uniform float final_mix : hint_range(0.0, 1.0) = 0.0;   // 0=蚕食期(黑暗限月内·无环冕) 1=成相(环+冕)
uniform float moon_mask_radius : hint_range(0.25, 0.6) = 0.395;  // 月面掩模半径(⚠须盖到月贴图像素阶梯边缘·太小=蚕食时蓝边残留)
uniform vec4 disc_color : source_color = vec4(0.03, 0.02, 0.06, 1.0);      // 暗盘芯色(近黑微紫)
uniform vec4 disc_edge_color : source_color = vec4(0.16, 0.1, 0.3, 1.0);   // 暗盘缘透光(深紫)
uniform vec4 rim_color : source_color = vec4(0.85, 0.72, 1.0, 1.0);        // 盘缘亮环(紫白)
uniform vec4 corona_color : source_color = vec4(0.5, 0.34, 0.95, 1.0);     // 外冕柔光(紫)
uniform float disc_radius : hint_range(0.1, 0.5) = 0.36;     // 暗盘半径(UV 比例)
uniform float rim_width : hint_range(0.001, 0.1) = 0.018;    // 亮环厚度基准(高斯σ·UV 比例)
uniform float rim_intensity : hint_range(0.0, 3.0) = 1.0;    // 亮环强度(成相小炸时代码短冲 >1)
uniform float corona_reach : hint_range(0.0, 0.5) = 0.22;    // 外冕伸展(UV 比例)
uniform float corona_intensity : hint_range(0.0, 1.0) = 0.5; // 外冕强度
uniform float breath_amount : hint_range(0.0, 0.3) = 0.08;   // 外冕呼吸幅度(光的呼吸·非律动)
uniform float breath_speed : hint_range(0.0, 2.0) = 0.25;    // 呼吸/流转速度(极慢)
uniform float grain_px : hint_range(1.0, 8.0) = 2.0;         // 细粒吸附(px·贴像素但不成方块)
uniform float crack_px : hint_range(2.0, 16.0) = 7.0;        // 裂缝专用粗格(px·裂纹边缘走台阶=像素感·与烟云语言对齐)


void fragment() {
	vec2 p = floor(UV * size_px / grain_px) * grain_px / size_px;
	float ph = TIME * breath_speed * 6.2832;
	vec2 c = p - vec2(0.5);
	float rm = length(c);
	float ang = atan(c.y, c.x);
	// —— 蚕食期：黑暗自月缘四周向心吞噬·前沿=多谐波指状（⛔正圆收缩环）——
	// rag ∈ ~[0.78,1.22]：各角度吞噬深浅不一 → 有的方位先被咬出缺口·指状前沿缓慢蠕动
	float rag = 1.0 + 0.10 * sin(ang * 3.0 + 1.7) + 0.07 * sin(ang * 5.0 - 0.9)
		+ 0.05 * sin(ang * 8.0 + ph * 0.5);
	float on_moon = 1.0 - smoothstep(moon_mask_radius - 0.012, moon_mask_radius + 0.015, rm);
	float front = clamp(moon_mask_radius * (1.0 - eat) * rag, 0.0, moon_mask_radius);
	float bite = smoothstep(front - 0.02, front + 0.02, rm);
	bite *= on_moon;
	bite *= smoothstep(0.0, 0.06, eat);   // eat=0 保证完月（rag<1 方位不提前咬）
	// 裂缝段：黑色裂纹自月缘向心伸展（~7 条不均匀分布·长短不一·沿径扭动+微微蠕动·⛔直线放射条）
	// 裂纹专用粗格坐标+硬边阈值 → 边缘走 crack_px 台阶（像素感·治"滑溜溜"·Eddy 2026-07-11 六改）
	vec2 pc = floor(UV * size_px / crack_px) * crack_px / size_px;
	vec2 cc = pc - vec2(0.5);
	float rm_c = length(cc);
	float ang_c = atan(cc.y, cc.x);
	float za = ang_c + 0.10 * sin(rm_c * 34.0 + ang_c * 2.0) + 0.04 * sin(ph * 2.0 + ang_c * 4.0);
	float spikes = cos(za * 7.0 + 1.3 * sin(za * 3.0 + 0.7));
	float cw = smoothstep(0.925, 0.945, spikes);
	float clen = 0.62 + 0.25 * sin(ang_c * 5.0 + 2.4);   // 每条伸展深度不一
	float tip = moon_mask_radius * (1.0 - crack * clen);
	float on_moon_c = 1.0 - smoothstep(moon_mask_radius - 0.012, moon_mask_radius + 0.015, rm_c);
	float crk = cw * smoothstep(tip, tip + 0.02, rm_c) * step(0.001, crack) * on_moon_c;
	float dark_pre = max(bite, crk);
	vec3 bite_col = mix(disc_edge_color.rgb, disc_color.rgb, smoothstep(front, front + 0.14, rm));
	// —— 成相期：暗盘（盘缘轻微不圆·反正圆 LED）——
	float wob = 1.0 + 0.010 * sin(ang * 3.0 + ph * 0.9) + 0.006 * sin(ang * 7.0 - ph * 0.6);
	float dr = disc_radius * wob;
	float edge_soft = 1.5 / size_px.x;
	float disc = 1.0 - smoothstep(dr - edge_soft, dr + edge_soft, rm);
	vec3 disc_col = mix(disc_color.rgb, disc_edge_color.rgb, smoothstep(dr * 0.55, dr, rm));
	// 两相位合成（蚕食全噬后 front→0 与暗盘几何几乎重合 → 切换无缝）
	float dark_a = mix(dark_pre, disc, final_mix);
	vec3 dark_col = mix(bite_col, disc_col, final_mix);
	// 盘缘亮环：高斯细环·环宽+亮度角向双频流转（光斑游走·幅度压低保"光感"）
	float w_var = rim_width * (1.0 + 0.30 * sin(ang * 5.0 - ph * 0.5) * sin(ang * 2.0 + ph * 0.8));
	float ring = exp(-pow((rm - dr) / max(w_var, 0.004), 2.0)) * rim_intensity;
	ring *= 0.68 + 0.32 * sin(ang * 3.0 + ph * 0.7) * sin(ang * 5.0 - ph * 0.45);
	ring *= step(dr - w_var, rm) * final_mix;
	// 外冕：柔光平滑衰减 + 呼吸 + 角向轻微不均
	float breath = 1.0 + breath_amount * sin(ph);
	float cor = (1.0 - smoothstep(0.0, corona_reach * breath, rm - dr)) * corona_intensity;
	cor *= step(dr, rm);
	cor *= cor;
	cor *= (0.85 + 0.15 * sin(ang * 2.0 - ph * 0.4)) * final_mix;
	vec3 col = dark_col * dark_a + rim_color.rgb * ring + corona_color.rgb * cor;
	float a = clamp(dark_a + ring + cor, 0.0, 1.0);
	COLOR = vec4(col, a);
}
