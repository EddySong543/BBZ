shader_type canvas_item;
render_mode blend_add;

// =============================================================
// canvas_env_light_shaft.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 月光丁达尔光束（概念版·2026-07-09 Eddy 点单 A）
//   1 主 + 1 副两道斜向月光柱，自月亮方向斜落到中央对峙屋脊，落点亲到既有受光斑
//   （canvas_fx_moonlight patch）→ 光源/介质（雾带）/落点结构逻辑闭环。
//   ⚠ 反"脏"与性能纪律：局部 quad（非全屏·不抓后台缓冲）·加法混合低强度封顶·
//     内部浓淡=双频 sin 极慢流动（同雾带手法·无噪点）·grain 像素粗格贴像素风。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 每像素 2 次 sin + 数次点积 → 极低。
// 无变体/关键字。坐标系=节点局部 px（size_px 须与 .tscn 节点矩形尺寸一致）。
// =============================================================

uniform vec2 size_px = vec2(860.0, 540.0);            // 节点矩形尺寸(px·UV→局部px 换算)
uniform vec2 beam_from = vec2(568.0, 84.0);            // 主束起点(局部px·月亮盘缘沿光向)
uniform vec2 beam_to = vec2(320.0, 420.0);             // 主束落点(局部px·对峙屋脊受光斑)
uniform vec4 shaft_color : source_color = vec4(0.62, 0.78, 1.0, 1.0);  // 月光冷蓝（与受光斑同族）
uniform float intensity : hint_range(0.0, 0.3) = 0.11; // 主束最浓强度（加法混合·反脏封顶）
uniform float width_main : hint_range(10.0, 200.0) = 66.0;   // 主束半宽(px)
uniform float width_side : hint_range(5.0, 100.0) = 26.0;    // 副束半宽(px)
uniform float side_offset : hint_range(-300.0, 300.0) = 118.0;  // 副束垂直轴偏距(px)
uniform float side_gain : hint_range(0.0, 1.0) = 0.45; // 副束相对主束强度
uniform float edge_soft : hint_range(0.05, 1.0) = 0.55;  // 边缘软度（半宽的比例）
uniform float flow_speed : hint_range(0.0, 0.05) = 0.008; // 内部浓淡流动速度（极慢）
uniform float grain_px : hint_range(1.0, 8.0) = 3.0;   // 像素粗格(px)：边缘出阶梯感贴像素风
uniform float fade_head : hint_range(0.0, 400.0) = 130.0;  // 起点淡入长度(px·从月晕里"长"出)
uniform float fade_tail : hint_range(0.0, 400.0) = 170.0;  // 落点淡出长度(px·亲到屋脊前收掉)


void fragment() {
	// 采样点吸附 grain 网格 → 光束边缘呈像素阶梯（非平滑矢量感）
	vec2 p = floor(UV * size_px / grain_px) * grain_px;
	vec2 axis = beam_to - beam_from;
	float len = length(axis);
	vec2 dirn = axis / len;
	vec2 perp = vec2(-dirn.y, dirn.x);
	vec2 rel = p - beam_from;
	float t = dot(rel, dirn);   // 沿束距离
	float d = dot(rel, perp);   // 垂直偏距
	// 沿束淡入淡出：起点从月晕方向渐显 → 落点在屋脊前收干净（不涂到瓦面上）
	float along = smoothstep(0.0, fade_head, t) * (1.0 - smoothstep(len - fade_tail, len, t));
	// 主束 + 副束横截面（软边·无动态分支）
	float soft_m = width_main * edge_soft;
	float band_m = 1.0 - smoothstep(width_main - soft_m, width_main + soft_m, abs(d));
	float soft_s = width_side * edge_soft;
	float band_s = (1.0 - smoothstep(width_side - soft_s, width_side + soft_s, abs(d - side_offset))) * side_gain;
	// 内部浓淡流动：双频 sin 缓慢滑动（0.72 基底 + 0.28 起伏 → 永不全灭·同雾带配比思路）
	float ph = TIME * flow_speed * 6.2832;
	float flow = 0.72 + 0.28 * sin(d * 0.045 + ph) * sin(t * 0.011 - ph * 0.7);
	float a = clamp(band_m + band_s, 0.0, 1.0) * along * flow * intensity;
	COLOR = vec4(shaft_color.rgb, a);
}
