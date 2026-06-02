shader_type canvas_item;
render_mode blend_add;

// =============================================================
// canvas_fx_window_light.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 宝塔 4 橙窗暖光 + 体积光（叠加在塔贴图上）
//   塔身贴图自带 4 个橙色窗口（非单一光源）。本着色器在塔区域叠一层：每个窗口 =
//   ① 紧致暖光晕（克制：半径小、不发散）② 沿光束方向的短促体积光束（god-ray 风格丁达尔）。
//   additive 暖橙 + 烛火般轻微 flicker。挂在与 Tower 等大对齐的 ColorRect 上 →
//   本地 UV 与塔贴图一一对应，4 个 winN 即 4 个窗口的归一化位置（可在 Inspector 微调对位）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 4 窗 ×(几条算式 + exp)、仅塔区域 → 低。
//   (无循环 / 无纹理采样 / step 取代向前分支，符合性能规范；不会吃回之前的降温)
// =============================================================

group_uniforms windows;  // 4 个窗口在本地 UV 的位置（右=+x，下=+y），对准塔贴图的橙窗
uniform vec2 win1 = vec2(0.40, 0.46);
uniform vec2 win2 = vec2(0.60, 0.46);
uniform vec2 win3 = vec2(0.35, 0.63);
uniform vec2 win4 = vec2(0.65, 0.63);
uniform float aspect = 0.9375;   // 矩形 宽/高，校正圆形光晕不被拉成椭圆

group_uniforms glow;  // 窗口光晕（克制 = 半径小）
uniform vec4 light_color : source_color = vec4(1.0, 0.58, 0.26, 1.0);
uniform float glow_radius : hint_range(0.004, 0.15) = 0.028;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.0;

group_uniforms shaft;  // 体积光束（克制 = 短）
uniform vec2 shaft_dir = vec2(0.05, 1.0);   // 光束方向（默认朝下略偏）
uniform float shaft_length : hint_range(0.0, 0.8) = 0.16;
uniform float shaft_width : hint_range(0.004, 0.12) = 0.018;
uniform float shaft_intensity : hint_range(0.0, 2.0) = 0.45;

group_uniforms flicker;  // 烛火般轻微闪
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.08;
uniform float flicker_speed : hint_range(0.0, 6.0) = 2.3;

// 单个窗口的光 = 紧致光晕 + 沿 dir 的短体积光束。
float window_light(vec2 uv, vec2 w, vec2 dir) {
	vec2 d = uv - w;
	// 紧致径向光晕（高斯），x 乘 aspect 保证视觉上是圆
	vec2 da = vec2(d.x * aspect, d.y);
	float glow = exp(-dot(da, da) / (glow_radius * glow_radius)) * glow_intensity;
	// 体积光束：沿 dir 投影，长度二次衰减 × 宽度高斯衰减；step 取代"只向前"分支
	float along = dot(d, dir);
	vec2 perp = d - dir * along;
	vec2 pa = vec2(perp.x * aspect, perp.y);
	float fwd = step(0.0, along);
	float len_fall = max(0.0, 1.0 - along / shaft_length);
	float beam = fwd * len_fall * len_fall
		* exp(-dot(pa, pa) / (shaft_width * shaft_width)) * shaft_intensity;
	return glow + beam;
}

void fragment() {
	float t = TIME * flicker_speed;
	vec2 dir = normalize(shaft_dir);
	// 每窗错相位的烛火闪（1 - 抖动）
	float f1 = 1.0 - flicker_amount * (0.5 + 0.5 * sin(t + 0.0));
	float f2 = 1.0 - flicker_amount * (0.5 + 0.5 * sin(t + 1.7));
	float f3 = 1.0 - flicker_amount * (0.5 + 0.5 * sin(t + 3.1));
	float f4 = 1.0 - flicker_amount * (0.5 + 0.5 * sin(t + 4.6));
	float l = window_light(UV, win1, dir) * f1
		+ window_light(UV, win2, dir) * f2
		+ window_light(UV, win3, dir) * f3
		+ window_light(UV, win4, dir) * f4;
	COLOR = vec4(light_color.rgb * l, 1.0);  // additive（render_mode blend_add）
}
