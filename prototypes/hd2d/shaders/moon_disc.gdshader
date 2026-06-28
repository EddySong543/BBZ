// HD-2D 原型：明月圆盘（广告牌 + 月海暗斑 + 边缘减光，HDR 亮度喂辉光出月晕）
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 moon_color : source_color = vec3(0.98, 0.96, 0.88);
uniform float intensity = 1.7;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float disc = smoothstep(1.0, 0.9, d);
	// 月海暗斑（三块固定暗椭圆，足够卖出"月亮"轮廓）
	float maria = smoothstep(0.45, 0.1, length(p - vec2(-0.25, 0.15))) * 0.18
		+ smoothstep(0.35, 0.08, length(p - vec2(0.2, -0.2))) * 0.14
		+ smoothstep(0.3, 0.06, length(p - vec2(0.15, 0.35))) * 0.10;
	float limb = 1.0 - 0.25 * smoothstep(0.5, 1.0, d);  // 边缘减光
	ALBEDO = moon_color * (1.0 - maria) * limb * intensity;
	ALPHA = disc;
}
