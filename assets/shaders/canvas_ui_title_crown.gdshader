shader_type canvas_item;

// 王冠扫光（title_logo.gd 专用）：白光带掠过王冠，与标题字身扫光共用同一坐标系
// （全标题归一化 x），只提亮明亮像素——黑描边按亮度阈值剔除，保持像素轮廓。
// 复杂度：零额外纹理采样（基于内建 COLOR），无分支；目标平台 PC（boot 一次性场景）。

uniform float sheen_pos = -1.0;      // 光带中心（-0.15→1.15 扫过全标题；-1=隐藏）
uniform float sheen_width : hint_range(0.01, 0.5) = 0.10;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.6;
uniform float x_offset = 0.0;        // 王冠左缘在标题内的 x 偏移(px)
uniform float title_width = 1.0;     // 标题总宽(px)

varying float v_gx;

void vertex() {
	v_gx = (VERTEX.x + x_offset) / title_width;
}

void fragment() {
	float band = 1.0 - smoothstep(0.0, sheen_width, abs(v_gx - sheen_pos));
	float lum = max(COLOR.r, max(COLOR.g, COLOR.b));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), band * sheen_strength * step(0.25, lum));
}
