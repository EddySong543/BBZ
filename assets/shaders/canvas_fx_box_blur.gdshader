shader_type canvas_item;

// =============================================================
// canvas_fx_box_blur.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 前景屋脊的失焦虚化（近景 out-of-focus）
//   对整张贴图 rgb+alpha 做 9-tap 高斯加权模糊 → 近景屋檐呈柔焦（非仅羽化边缘），
//   配合 self_modulate 压暗 → 读作"贴近镜头、失焦的前景剪影"。
//   挂在 scene1 的近景屋脊(closeRf*)material 上；blur_amount 越大越糊。
//   silhouette：把贴图内部烘焙光影压平成纯色剪影 → 抹掉"近景却自带月光高光"的矛盾死光。
//   brightness：乘法提亮 → 即使原图是暗色，也能把某片屋脊照成"受月光的亮屋脊"。
//   末尾乘 COLOR 保留 self_modulate(近远染色/压暗仍生效；剪影色即由 self_modulate 决定)。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 9 次纹理采样、仅屋脊 quad → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item）。单遍 3x3（与 edge_soften 同级，非全屏高斯）。
// =============================================================

uniform float blur_amount : hint_range(0.0, 8.0) = 2.0;  // 模糊半径(纹理像素)；越大越糊，0=不糊
uniform float silhouette : hint_range(0.0, 1.0) = 0.0;   // 剪影化：抹平贴图烘焙光影→纯剪影(由 self_modulate 上色)；0=保留贴图死光，1=完全压平
uniform float brightness : hint_range(0.0, 4.0) = 1.0;   // 提亮(乘法增益)：暗色贴图也能照亮成"受月光的亮屋脊"；1=原样，>1 变亮

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;
	// 3x3 高斯加权（中心 0.25 / 四边各 0.125 / 四角各 0.0625，权重和=1）
	vec4 c = texture(TEXTURE, UV) * 0.25;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.125;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.125;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.125;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.125;
	c += texture(TEXTURE, UV + px) * 0.0625;
	c += texture(TEXTURE, UV - px) * 0.0625;
	c += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.0625;
	c += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.0625;
	// 提亮：乘法增益，让暗色贴图也能被"照亮"成受月光的亮屋脊。
	c.rgb *= brightness;
	// 剪影化：把 rgb 拉向平坦(1.0)抹掉烘焙高光，随后乘 COLOR(self_modulate)
	// → 整片变成 self_modulate 指定的暗冷剪影色，消除"近景却带月光高光"的矛盾。
	c.rgb = mix(c.rgb, vec3(1.0), silhouette);
	COLOR = c * COLOR;
}
