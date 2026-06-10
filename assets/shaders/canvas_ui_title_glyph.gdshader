shader_type canvas_item;

// 标题字专用渐变（title_logo.gd）：字身纵向金色渐变 + flash 白闪。
// 用途：boot 标题「波波攒之王」统一配色（2026-06-10 Eddy 决议：单色系增质感，弃多彩）。
// 原理：Label 字身 pass 顶点色=白 → 乘渐变后显出渐变；描边/投影 pass 顶点色为黑/深色
//      → 乘任何颜色仍保持深色，因此渐变只作用于字身。
// 复杂度：单次纹理采样 + 两次 mix，无分支；目标平台 PC（boot 一次性场景）。

uniform vec3 top_color : source_color = vec3(1.0, 0.88, 0.55);    // 字身顶部 亮金
uniform vec3 bottom_color : source_color = vec3(0.82, 0.53, 0.13); // 字身底部 深琥珀
uniform float glyph_height = 120.0;  // 字面高度(px)：把顶点 y 归一化为渐变参数
uniform float flash : hint_range(0.0, 1.0) = 0.0;  // 1=字身打白（落地闪/金光）

group_uniforms sheen;  // 白光扫过（连击冲击 / 待机定期掠光），坐标系=全标题归一化 x
uniform float sheen_pos = -1.0;      // 光带中心（-0.15→1.15 扫过全标题；-1=隐藏）
uniform float sheen_width : hint_range(0.01, 0.5) = 0.10;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.6;
uniform float x_offset = 0.0;        // 本字左缘在标题内的 x 偏移(px)
uniform float title_width = 1.0;     // 标题总宽(px)

varying float v_y;
varying float v_gx;

void vertex() {
	v_y = VERTEX.y / glyph_height;
	v_gx = (VERTEX.x + x_offset) / title_width;
}

void fragment() {
	vec3 grad = mix(top_color, bottom_color, clamp(v_y, 0.0, 1.0));
	// 扫光并入 flash 通道（与渐变相乘）→ 黑描边/投影天然不受影响
	float band = 1.0 - smoothstep(0.0, sheen_width, abs(v_gx - sheen_pos));
	float fl = max(flash, band * sheen_strength);
	COLOR.rgb *= mix(grad, vec3(1.0), fl);
}
