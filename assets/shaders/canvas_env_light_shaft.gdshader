shader_type canvas_item;
render_mode blend_add;

// =============================================================
// canvas_env_light_shaft.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 月光投光锥（v2 重设计·2026-07-11 Eddy 定向）
//   一束月光从高处（锥顶藏在月后）投到 rooftop 对峙面，锥体向下张开，
//   到脚线处罩住 P1+P2 双雄（强调角色）。取代 v1 平行光带（等宽=读作发光长方形·已废）。
//   ⚠ 反"脏"与性能纪律：局部 quad（非全屏·不抓后台缓冲）·加法混合低强度封顶·
//     锥体半宽随垂距线性增长（无平行边）·grain 像素粗格贴像素风。
//   ⚠ 防矩形切边铁律：所有衰减必须在节点矩形内自然归零（head/tail 淡出+锥缘 r>1 归零），
//     调参后需自查四缘（2026-07-11 v1 加宽出界切边教训）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 每像素 2 次 sin + 数次乘除 → 极低。
// 无变体/关键字。坐标系=节点局部 px（size_px 须与 .tscn 节点矩形尺寸一致）。
// =============================================================

uniform vec2 size_px = vec2(1520.0, 500.0);            // 节点矩形尺寸(px·UV→局部px 换算)
uniform vec2 apex_px = vec2(760.0, -820.0);            // 锥顶(局部px·允许在节点外·藏于月后高处)
uniform float cone_tan : hint_range(0.1, 1.5) = 0.55;  // 锥体扩散率(半宽/垂距)：越大越张开
uniform vec4 shaft_color : source_color = vec4(0.62, 0.78, 1.0, 1.0);  // 月光冷蓝（与受光斑同族）
uniform float intensity : hint_range(0.0, 0.3) = 0.14; // 光轴最浓强度（加法混合·反脏封顶）
uniform float core_soft : hint_range(0.0, 0.9) = 0.25; // 中心平台占比：r<此值=满强·r=1 锥缘归零
uniform vec2 head_fade = vec2(10.0, 150.0);            // 顶部淡入区间(局部y px·从月晕方向渐显)
uniform vec2 tail_fade = vec2(400.0, 480.0);           // 底部淡出区间(局部y px·屋面前收干净)
uniform float flow_speed : hint_range(0.0, 0.05) = 0.008; // 内部浓淡流动速度（极慢）
uniform float grain_px : hint_range(1.0, 8.0) = 3.0;   // 像素粗格(px)：边缘出阶梯感贴像素风


void fragment() {
	// 采样点吸附 grain 网格 → 光锥边缘呈像素阶梯（非平滑矢量感）
	vec2 p = floor(UV * size_px / grain_px) * grain_px;
	// 锥体横截面：半宽随距锥顶垂距线性增长 → 无平行边、越下越宽越弥散
	float dy = p.y - apex_px.y;                    // 锥顶在节点上方 → 节点内恒 >0
	float half_w = max(dy * cone_tan, 1.0);
	float r = abs(p.x - apex_px.x) / half_w;       // 0=光轴 1=锥缘
	float band = 1.0 - smoothstep(core_soft, 1.0, r);
	// 纵向淡入淡出：顶部从月晕里"长"出 → 底部在屋面反光斑接手前收掉
	float along = smoothstep(head_fade.x, head_fade.y, p.y)
		* (1.0 - smoothstep(tail_fade.x, tail_fade.y, p.y));
	// 内部浓淡流动：双频 sin 缓慢滑动（同雾带手法·永不全灭）
	float ph = TIME * flow_speed * 6.2832;
	float flow = 0.78 + 0.22 * sin(p.x * 0.012 + ph) * sin(p.y * 0.016 - ph * 0.7);
	COLOR = vec4(shaft_color.rgb, band * along * flow * intensity);
}
