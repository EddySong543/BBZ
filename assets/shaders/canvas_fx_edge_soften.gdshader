shader_type canvas_item;

// =============================================================
// canvas_fx_edge_soften.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 通用轮廓柔化（scene1 远山顶边）
//   模糊贴图 alpha 边缘 → 轮廓柔和渐隐；rgb 保留(山体内容不糊、仍是清晰剪影)。
//   用于柔化远山剪影的顶轮廓，化开"远山压住月盘下缘"的生硬交界线。
//   末尾乘顶点色，保留 modulate(山的 self_modulate 远近染色仍生效)。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 9 次纹理采样 → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

uniform float edge_blur : hint_range(0.0, 16.0) = 4.0;  // 柔边宽度(纹理像素，越大轮廓越柔)

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * edge_blur;
	vec4 c = texture(TEXTURE, UV);
	// 9-tap 模糊 alpha（柔化轮廓），rgb 用中心保留山体清晰
	float a = c.a * 0.196;
	a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a * 0.118;
	a += texture(TEXTURE, UV - vec2(px.x, 0.0)).a * 0.118;
	a += texture(TEXTURE, UV + vec2(0.0, px.y)).a * 0.118;
	a += texture(TEXTURE, UV - vec2(0.0, px.y)).a * 0.118;
	a += texture(TEXTURE, UV + px).a * 0.083;
	a += texture(TEXTURE, UV - px).a * 0.083;
	a += texture(TEXTURE, UV + vec2(px.x, -px.y)).a * 0.083;
	a += texture(TEXTURE, UV + vec2(-px.x, px.y)).a * 0.083;
	COLOR = vec4(c.rgb, clamp(a, 0.0, 1.0)) * COLOR;
}
