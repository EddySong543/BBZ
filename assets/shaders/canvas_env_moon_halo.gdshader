shader_type canvas_item;

// =============================================================
// canvas_env_moon_halo.gdshader  (v7 静止·圆形 + 左下洒落)
// 作者: Claude (Game Studios) ｜ 用途: scene1 月亮辉光（局部"假 bloom"，全屏）
//   = 稳定圆形光晕 + 朝左下柔和延展。光晕本身保持静止（月光本就稳定）；
//   "月光在活"的动效改由月光中飘动的光尘(浮尘层)体现 —— 见 scene1 的 Dust。
//   只作用月亮这一层 —— 不波及角色/UI/其它场景。放月盘图之下，非辉光区 alpha=0 透出天空。
// 目标平台: PC (Windows D3D12 / Forward+)。
// 复杂度预算: 全屏 1 pass、纯算术 —— 开销极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合）。
// =============================================================

group_uniforms placement;
uniform vec2 moon_pos = vec2(0.745, 0.16);                   // 月心（与月亮图一致）
uniform float halo_size : hint_range(0.03, 0.6) = 0.18;     // 光晕尺度
group_uniforms;

group_uniforms spill;  // 朝左下的柔和延展（非光柱）
uniform vec2 spill_dir = vec2(-1.0, 1.0);                   // 洒落方向（默认左下）
uniform float spill_stretch : hint_range(1.0, 4.0) = 1.4;   // 沿该方向拉伸程度（1=纯圆）
uniform float spill_strength : hint_range(0.0, 1.5) = 0.3;  // 延展光浓淡
group_uniforms;

group_uniforms look;
uniform vec4 halo_color : source_color = vec4(0.55, 0.66, 0.92, 1.0);
uniform float halo_intensity : hint_range(0.0, 2.0) = 0.65;
group_uniforms;

group_uniforms flicker;  // 大气下月光的自然微闪：3 个不成比例的慢正弦叠加 → 无规律缓慢明灭（非机械呼吸、非条带）
uniform float flicker_amount : hint_range(0.0, 0.3) = 0.12;
uniform float flicker_speed : hint_range(0.0, 2.0) = 0.8;
group_uniforms;

group_uniforms rings;  // 把径向渐变量化成"可控的同心光环"（适当保留圆环美感，而非失控 banding）
uniform int ring_steps : hint_range(2, 64) = 14;             // 同心光环层数（少=粗环明显保留，64≈平滑无环）
uniform float dither_strength : hint_range(0.0, 1.5) = 1.0;  // 环边界软化（1=柔和，0=硬边明显）
group_uniforms;

const float BAYER_4X4[16] = float[](
	0.0,  8.0,  2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0,  9.0, 15.0, 7.0, 13.0, 5.0);
float bayer(vec2 frag) {
	ivec2 p = ivec2(mod(frag, 4.0));
	return (BAYER_4X4[p.y * 4 + p.x] / 16.0) - 0.5;
}

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;
	vec2 d = UV - moon_pos;
	d.x *= aspect;                                  // 以高度归一化 → 圆形光晕
	float dist = length(d);

	// 1) 稳定圆形核心光晕（对称，月亮周围）
	float core = exp(-dist / max(halo_size * 0.5, 0.001)) * 0.7;

	// 2) 朝 spill_dir(左下) 柔和拉伸的洒落光（椭圆，非光柱）
	vec2 dir = normalize(spill_dir);
	float proj = dot(d, dir);
	vec2 perp = d - proj * dir;
	float k = (proj > 0.0) ? spill_stretch : 1.0;
	float ed = length(vec2(proj / k, length(perp)));
	float spill = exp(-ed / max(halo_size, 0.001)) * spill_strength;

	float glow = (core + spill) * halo_intensity;
	// 大气微闪：3 个不成比例频率的慢正弦叠加 → 无规律缓慢明灭（自然 flicker，非机械呼吸/条带）
	float t = TIME * flicker_speed;
	float flicker = (sin(t * 0.7) + sin(t * 1.13 + 2.1) + sin(t * 0.41 + 4.3)) * 0.333;
	glow *= 1.0 + flicker * flicker_amount;
	// 量化成可控的同心光环(ring_steps 圈) + 抖动软化环边界（dithered posterize）
	float rs = float(ring_steps);
	glow = floor(glow * rs + bayer(FRAGCOORD.xy) * dither_strength + 0.5) / rs;
	COLOR = vec4(halo_color.rgb, clamp(glow, 0.0, 1.0));
}
