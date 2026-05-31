shader_type canvas_item;

// =============================================================
// canvas_env_moon_halo.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 月亮周围的辉光晕（放在月盘图片之下，全屏）
//   月盘本体仍是图片(Scene1_moon.png)；本层只画月亮四周的柔光晕 + 极缓慢一胀一缩脉动，
//   给深夜月亮加氛围光、破"太静"。非光晕区 alpha=0 透出天空。
// 目标平台: PC (Windows D3D12 / Forward+)。
// 复杂度预算: 全屏 1 pass、纯算术 —— 开销极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，TIME 驱动脉动，alpha 混合）。
// =============================================================

group_uniforms placement;
uniform vec2 moon_pos = vec2(0.72, 0.20);                    // 月心（与月亮图一致）
uniform float halo_radius : hint_range(0.05, 0.5) = 0.17;    // 光晕半径（屏幕高度比例）
uniform float halo_falloff : hint_range(0.5, 4.0) = 2.2;     // 衰减曲线（越大边缘越收）
group_uniforms;

group_uniforms look;
uniform vec4 halo_color : source_color = vec4(0.50, 0.62, 0.85, 1.0);
uniform float halo_intensity : hint_range(0.0, 1.5) = 0.4;
group_uniforms;

group_uniforms pulse;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.5;      // 脉动速度（缓慢呼吸）
uniform float pulse_amount : hint_range(0.0, 0.4) = 0.12;    // 脉动幅度
group_uniforms;

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;
	vec2 d = UV - moon_pos;
	d.x *= aspect;                                  // 以高度归一化 → 圆形光晕
	float dist = length(d);

	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	float r = halo_radius * pulse;
	float halo = pow(clamp(1.0 - dist / max(r, 0.001), 0.0, 1.0), halo_falloff);
	halo *= halo_intensity * (1.0 + sin(TIME * pulse_speed) * pulse_amount * 0.5);

	COLOR = vec4(halo_color.rgb, clamp(halo, 0.0, 1.0));
}
