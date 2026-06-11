shader_type canvas_item;

// 标题字专用着色（title_logo.gd）：分档金色阶 + 笔画浮雕棱线 + flash 白闪 + 扫光。
// 2026-06-11 反"PPT 艺术字"重做（Eddy 批 A+B）：
//   A 分档金：连续渐变 → 4 档硬色带 + 字体像素级 Bayer 2×2 抖动过渡（像素游戏的金=色阶感）
//   B 伪浮雕：采样字形 alpha 邻域，笔画上缘 1 字体像素亮棱 / 下缘暗棱（顶光金属字）
// 原理：Label 字身 pass 顶点色=白 → 乘色阶后显出金；描边/投影 pass 顶点色为深色
//      → 乘任何亮度因子仍保持深色，因此色阶/棱线只作用于字身。
// 复杂度：3 次纹理采样 + 少量分支；目标平台 PC（boot 一次性场景）。

uniform float glyph_height = 120.0;  // 字面高度(px)：把顶点 y 归一化为色阶参数
uniform float px_size = 10.0;        // 1 字体像素 = 多少屏幕像素（= font_size / 12）
uniform float flash : hint_range(0.0, 1.0) = 0.0;  // 1=字身打白（落地闪/金光）

group_uniforms sheen;  // 白光扫过（连击冲击 / 待机定期掠光），坐标系=全标题归一化 x
uniform float sheen_pos = -1.0;      // 光带中心（-0.15→1.15 扫过全标题；-1=隐藏）
uniform float sheen_width : hint_range(0.01, 0.5) = 0.10;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.6;
uniform float x_offset = 0.0;        // 本字左缘在标题内的 x 偏移(px)
uniform float title_width = 1.0;     // 标题总宽(px)

varying float v_y;
varying float v_gx;
varying vec2 v_pix;                  // Label 本地像素坐标（抖动网格随字走·不随屏幕爬动）

// 金色阶 4 档：亮金 / 主金 / 深金 / 暗琥珀
const vec3 G0 = vec3(1.00, 0.878, 0.541);
const vec3 G1 = vec3(0.957, 0.784, 0.294);
const vec3 G2 = vec3(0.784, 0.525, 0.165);
const vec3 G3 = vec3(0.541, 0.329, 0.078);

void vertex() {
	v_y = VERTEX.y / glyph_height;
	v_gx = (VERTEX.x + x_offset) / title_width;
	v_pix = VERTEX.xy;
}

// Bayer 2×2（0..3 → 0..1）：档位边界棋盘交错
float bayer2(vec2 c) {
	vec2 p = mod(c, 2.0);
	float i = p.y * 2.0 + p.x;
	float v = i < 0.5 ? 0.0 : (i < 1.5 ? 2.0 : (i < 2.5 ? 3.0 : 1.0));
	return (v + 0.5) / 4.0;
}

void fragment() {
	// A 分档金：字体像素粒度 Bayer 抖动 → 档位边界犬牙交错
	float dith = bayer2(floor(v_pix / max(px_size, 1.0)));
	float yq = clamp(v_y, 0.0, 1.0) + (dith - 0.5) * 0.12;
	vec3 grad = G3;
	if (yq < 0.24) {
		grad = G0;
	} else if (yq < 0.52) {
		grad = G1;
	} else if (yq < 0.78) {
		grad = G2;
	}

	// B 伪浮雕：笔画上缘亮棱 / 下缘暗棱（按字体像素步长采样邻域；上缘优先）
	vec2 off = vec2(0.0, TEXTURE_PIXEL_SIZE.y * px_size);
	float a_here = texture(TEXTURE, UV).a;
	float a_up = texture(TEXTURE, UV - off).a;
	float a_dn = texture(TEXTURE, UV + off).a;
	float top_e = step(0.5, a_here) * (1.0 - step(0.5, a_up));
	float bot_e = step(0.5, a_here) * (1.0 - step(0.5, a_dn)) * (1.0 - top_e);
	grad *= 1.0 + top_e * 0.33 - bot_e * 0.30;

	// 扫光并入 flash 通道（与色阶相乘）→ 深色描边/投影天然不受影响
	float band = 1.0 - smoothstep(0.0, sheen_width, abs(v_gx - sheen_pos));
	float fl = max(flash, band * sheen_strength);
	COLOR.rgb *= mix(grad, vec3(1.0), fl);
}
