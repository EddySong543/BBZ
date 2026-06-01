shader_type canvas_item;

// =============================================================
// canvas_fx_blur.gdshader  (v2: 模糊 + 大气透视雾化)
// 作者: Claude (Game Studios) ｜ 用途: scene1 景深背景"推远"——轻量高斯模糊 + 大气透视
//   作用于背景屋顶层 TextureRect。把偏清晰、对比偏高的贴图推到焦平面之后，靠两件事：
//     1) 单遍 13-tap 近似高斯模糊（背景元素面积小、PC → 单遍足够）。
//     2) 大气透视雾化：往夜空大气色混合 → 降对比、融入夜色。
//        ★ 这是 HD-2D 推远的正解：远景不是"更黑"，而是"更接近大气色"。越远 atmosphere_amount 越大。
//   焦平面(主屋顶)不挂此材质，保持锐利明亮。COLOR 乘回顶点色以保留 self_modulate。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 13 次纹理采样/像素、作用面积小 → 低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，采样节点自身 TEXTURE）。
// =============================================================

uniform float blur_radius : hint_range(0.0, 6.0) = 2.0;                        // 模糊半径(源纹理像素)；越远越大
uniform vec4 atmosphere_color : source_color = vec4(0.10, 0.13, 0.22, 1.0);    // 夜空大气色(蓝灰)
uniform float atmosphere_amount : hint_range(0.0, 1.0) = 0.3;                  // 雾化强度(降对比/融入)；越远越大

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 c = vec4(0.0);
	// 归一化 13-tap 高斯（中心 + 十字 + 对角 + 远十字）
	c += texture(TEXTURE, UV)                          * 0.1531;
	c += texture(TEXTURE, UV + vec2( ps.x, 0.0))       * 0.1224;
	c += texture(TEXTURE, UV + vec2(-ps.x, 0.0))       * 0.1224;
	c += texture(TEXTURE, UV + vec2(0.0,  ps.y))       * 0.1224;
	c += texture(TEXTURE, UV + vec2(0.0, -ps.y))       * 0.1224;
	c += texture(TEXTURE, UV + vec2( ps.x,  ps.y))     * 0.0747;
	c += texture(TEXTURE, UV + vec2(-ps.x,  ps.y))     * 0.0747;
	c += texture(TEXTURE, UV + vec2( ps.x, -ps.y))     * 0.0747;
	c += texture(TEXTURE, UV + vec2(-ps.x, -ps.y))     * 0.0747;
	c += texture(TEXTURE, UV + vec2( 2.0 * ps.x, 0.0)) * 0.0146;
	c += texture(TEXTURE, UV + vec2(-2.0 * ps.x, 0.0)) * 0.0146;
	c += texture(TEXTURE, UV + vec2(0.0,  2.0 * ps.y)) * 0.0146;
	c += texture(TEXTURE, UV + vec2(0.0, -2.0 * ps.y)) * 0.0146;

	vec4 base = c * COLOR;  // 乘回顶点色(含 self_modulate)
	// 大气透视：不透明部分往大气色混合 → 降对比、融入夜空（推远，而非压黑）
	vec3 atmo = mix(base.rgb, atmosphere_color.rgb, atmosphere_amount);
	COLOR = vec4(atmo, base.a);
}
