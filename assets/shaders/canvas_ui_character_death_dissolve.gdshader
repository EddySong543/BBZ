shader_type canvas_item;

// 作用在 CharacterDisplay 的 SubViewportContainer 输出上，不覆盖各场景已有角色光照材质。
// 以原始 alpha 轮廓的四周为起点向内侵蚀；进度只做硬切阶梯，不做整体透明度退场。
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_from_right : hint_range(0.0, 1.0) = 1.0;
uniform float dissolve_steps : hint_range(4.0, 24.0) = 12.0;
uniform float block_columns : hint_range(32.0, 128.0) = 96.0;
uniform vec4 frontier_color : source_color = vec4(0.34, 0.30, 0.40, 0.72);

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 grid = vec2(block_columns);
	vec2 block = floor(UV * grid);
	vec2 block_uv = (block + vec2(0.5)) / grid;
	vec2 stride = vec2(1.0) / grid;

	// 四向多环 alpha 探测：越靠近角色真实轮廓，depth 越低，越早被侵蚀。
	// 不用 UV 矩形边缘，因此透明留白不会吃掉前半段的视觉进度。
	float center = texture(TEXTURE, block_uv).a;
	float ring_1 = min(min(texture(TEXTURE, block_uv + vec2(stride.x, 0.0)).a,
			texture(TEXTURE, block_uv - vec2(stride.x, 0.0)).a),
		min(texture(TEXTURE, block_uv + vec2(0.0, stride.y)).a,
			texture(TEXTURE, block_uv - vec2(0.0, stride.y)).a));
	float ring_2 = min(min(texture(TEXTURE, block_uv + vec2(stride.x * 2.0, 0.0)).a,
			texture(TEXTURE, block_uv - vec2(stride.x * 2.0, 0.0)).a),
		min(texture(TEXTURE, block_uv + vec2(0.0, stride.y * 2.0)).a,
			texture(TEXTURE, block_uv - vec2(0.0, stride.y * 2.0)).a));
	float ring_3 = min(min(texture(TEXTURE, block_uv + vec2(stride.x * 3.0, 0.0)).a,
			texture(TEXTURE, block_uv - vec2(stride.x * 3.0, 0.0)).a),
		min(texture(TEXTURE, block_uv + vec2(0.0, stride.y * 3.0)).a,
			texture(TEXTURE, block_uv - vec2(0.0, stride.y * 3.0)).a));
	float ring_4 = min(min(texture(TEXTURE, block_uv + vec2(stride.x * 4.0, 0.0)).a,
			texture(TEXTURE, block_uv - vec2(stride.x * 4.0, 0.0)).a),
		min(texture(TEXTURE, block_uv + vec2(0.0, stride.y * 4.0)).a,
			texture(TEXTURE, block_uv - vec2(0.0, stride.y * 4.0)).a));
	float silhouette_depth = center * (
			ring_1 * 0.36 + ring_2 * 0.28 + ring_3 * 0.22 + ring_4 * 0.14);
	float grain = hash21(block);
	float hit_edge_bias = mix(UV.x, 1.0 - UV.x, dissolve_from_right);
	float erosion_order = silhouette_depth * 0.82 + grain * 0.14 + hit_edge_bias * 0.04;
	float steps = max(1.0, dissolve_steps);
	float stepped_progress = floor(clamp(dissolve_progress, 0.0, 1.0) * steps + 0.0001) / steps;

	if (dissolve_progress >= 0.999 || (dissolve_progress > 0.0001 && erosion_order <= stepped_progress)) {
		discard;
	}
	if (dissolve_progress > 0.0001 && erosion_order <= stepped_progress + 1.0 / steps) {
		source.rgb = mix(source.rgb, frontier_color.rgb, frontier_color.a);
	}
	COLOR = source * COLOR;
}
