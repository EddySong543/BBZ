shader_type canvas_item;

// 新 item_frame 以单张金色美术作为明暗母版；按道具阶级重映射为蓝 / 紫 / 金。
// 只替换色相与明度，不改变贴图 alpha、轮廓、角套或像素细节。
uniform vec4 shadow_color : source_color = vec4(0.09, 0.15, 0.23, 1.0);
uniform vec4 mid_color : source_color = vec4(0.37, 0.53, 0.69, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.72, 0.82, 0.91, 1.0);

varying vec4 frame_modulate;

void vertex() {
	// fragment 阶段的 COLOR 已乘入原金色纹理；提前保存节点 modulate，避免金色再次污染蓝/紫映射。
	frame_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float lower = smoothstep(0.08, 0.58, lum);
	float upper = smoothstep(0.52, 0.94, lum);
	vec3 mapped = mix(shadow_color.rgb, mid_color.rgb, lower);
	mapped = mix(mapped, highlight_color.rgb, upper);
	COLOR = vec4(mapped, tex.a) * frame_modulate;
}
