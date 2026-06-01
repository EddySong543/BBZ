shader_type canvas_item;
render_mode blend_add;

// =============================================================
// canvas_post_godray.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 体积光/丁达尔（屏幕空间径向散射 god rays）
//   从月亮位置 light_pos 向外做径向散射：沿"像素→光源"方向多步采样画面，累加其中的
//   亮部(月辉)并衰减 → 形成光束。月被山遮挡时，光束自然从月盘露出部分/山缝射出（丁达尔）。
//   render_mode blend_add → additive 叠加到已绘制的世界上；放在 WorldGrab 之前，最终一并被 PostFX 调色。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 48 次屏幕采样/像素、全屏 → 中。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，配合 BackBufferCopy 读 SCREEN_TEXTURE）。
// =============================================================

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 light_pos = vec2(0.774, 0.385);            // 光源(月亮)位置 UV，须对准月盘
uniform float density : hint_range(0.1, 1.5) = 0.85;    // 采样步长(光束长度)
uniform float decay : hint_range(0.8, 1.0) = 0.94;      // 沿程衰减(小→光束短)
uniform float weight : hint_range(0.0, 1.0) = 0.4;      // 每步权重
uniform float exposure : hint_range(0.0, 1.0) = 0.22;   // 光束总强度
uniform float threshold : hint_range(0.0, 1.0) = 0.5;   // 亮部阈值(只散射够亮的月辉)
uniform vec4 ray_tint : source_color = vec4(0.6, 0.78, 1.0, 1.0); // 光束染色(月光冷蓝)

const int SAMPLES = 48;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 delta = (uv - light_pos) * density / float(SAMPLES);
	vec2 coord = uv;
	float illum = 1.0;
	vec3 ray = vec3(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		coord -= delta;                                  // 朝光源步进
		vec3 s = texture(screen_tex, coord).rgb;
		float lum = dot(s, vec3(0.299, 0.587, 0.114));
		s *= smoothstep(threshold, 1.0, lum);            // 仅保留亮部(月辉)
		ray += s * illum * weight;
		illum *= decay;
	}
	COLOR = vec4(ray * exposure * ray_tint.rgb, 1.0);    // additive 叠加
}
