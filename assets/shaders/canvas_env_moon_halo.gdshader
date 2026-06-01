shader_type canvas_item;

// =============================================================
// canvas_env_moon_halo.gdshader  (v8: ref9 大辉光)
// 作者: Claude (Game Studios) ｜ 用途: scene1 月亮大辉光（全屏 alpha 层，照亮中央天空）
//   参考 ref9：一轮巨大发光月亮——月心青白亮核 + 大范围青蓝柔晕，平滑连续(无同心光环)。
//   ★ 放在山之后(更远)→ 把月亮周围天空照成青白，远山剪影衬在这片亮天空前、靠强对比成形。
//   月盘图(Moon)画在本层之后(盖住辉光中心)→ 辉光主要表现为月盘外的大范围渐亮 + 月盘边缘青白亮边。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、纯算术 → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动微闪）。
// =============================================================

group_uniforms placement;
uniform vec2 moon_pos = vec2(0.9375, 0.424);   // 月心(UV，须对准月盘中心)
group_uniforms;

group_uniforms core;  // 亮核（过曝月心，月盘边缘青白）
uniform vec4 core_color : source_color = vec4(0.80, 0.92, 1.0, 1.0);
uniform float core_size : hint_range(0.05, 0.5) = 0.22;       // 亮核半径(≈月盘半径)
uniform float core_intensity : hint_range(0.0, 2.0) = 1.0;
group_uniforms;

group_uniforms glow;  // 大范围柔晕（照亮天空，ref9 灵魂）
uniform vec4 glow_color : source_color = vec4(0.30, 0.55, 0.85, 1.0); // 青蓝
uniform float glow_size : hint_range(0.2, 1.5) = 0.85;        // 辉光扩散半径(越大照得越广)
uniform float glow_intensity : hint_range(0.0, 1.5) = 0.6;
uniform float glow_falloff : hint_range(0.5, 4.0) = 2.2;      // 衰减陡度(小=更平更广)
group_uniforms;

group_uniforms flicker;  // 大气微闪（很轻）
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.04;
uniform float flicker_speed : hint_range(0.0, 2.0) = 0.6;
group_uniforms;

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;
	vec2 d = UV - moon_pos;
	d.x *= aspect;                       // 以高度归一 → 圆形辉光
	float dist = length(d);

	// 亮核：指数衰减的青白核心（月盘边缘亮）
	float core = exp(-dist / max(core_size, 0.001)) * core_intensity;
	// 大晕：幂次衰减的大范围青蓝柔光（照亮天空）
	float glow = pow(clamp(1.0 - dist / glow_size, 0.0, 1.0), glow_falloff) * glow_intensity;

	// 大气微闪（两个不成比例慢正弦 → 自然，非机械呼吸）
	float t = TIME * flicker_speed;
	float fl = (sin(t * 0.7) + sin(t * 1.13 + 2.1)) * 0.5;
	glow *= 1.0 + fl * flicker_amount;

	float total = core + glow;
	// 核心区偏青白、外围偏青蓝
	vec3 col = mix(glow_color.rgb, core_color.rgb, clamp(core / max(total, 0.001), 0.0, 1.0));
	COLOR = vec4(col, clamp(total, 0.0, 1.0));
}
