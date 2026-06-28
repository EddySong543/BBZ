// HD-2D 原型：程序化火苗（广告牌 + 加色混合 + HDR 发光喂辉光）
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 flame_color : source_color = vec3(1.0, 0.52, 0.16);
uniform float intensity = 3.5;

void vertex() {
	// 全向广告牌（火苗永远面向相机）
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV - vec2(0.5, 0.62);
	p.x *= 1.6;
	// 火苗顶部左右摆动
	p.x += sin(TIME * 9.0 + UV.y * 8.0) * 0.07 * (0.62 - UV.y);
	float d = length(p);
	float body = smoothstep(0.42, 0.05, d + (1.0 - UV.y) * 0.18);
	float core = smoothstep(0.22, 0.02, d + (1.0 - UV.y) * 0.10);
	float flick = 0.85 + 0.15 * sin(TIME * 13.0) * sin(TIME * 7.7 + 1.3);

	// unshaded 模式只输出 ALBEDO，HDR 值(>1)会被辉光拾取
	ALBEDO = (flame_color * body + vec3(1.0, 0.9, 0.6) * core) * intensity * flick;
	ALPHA = body;
}
