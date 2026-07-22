shader_type canvas_item;

// =============================================================
// Scene2 三段天河共用的单段瀑布。
// 外轮廓保持稳定；内部水帘以少量离散帧循环，透明薄帘、长水丝、断续亮带和
// 边缘水滴各自运动。撞击区由像素泡沫簇组成，不使用平滑发光椭圆。
// 三份实例穿插在远/中/近山之间，由山体美术负责遮断段与段的连接。
// =============================================================

group_uniforms layout;
uniform vec2 size_px = vec2(520.0, 440.0);
uniform float px_size : hint_range(1.0, 12.0) = 4.0;
uniform float center_x : hint_range(0.0, 1.0) = 0.5;
uniform float top_y : hint_range(-0.25, 0.5) = 0.0;
uniform float bottom_y : hint_range(0.35, 1.1) = 0.78;
uniform float top_half_width_px : hint_range(8.0, 160.0) = 34.0;
uniform float bottom_half_width_px : hint_range(8.0, 180.0) = 52.0;
uniform float bend_px : hint_range(-80.0, 80.0) = -10.0;
uniform float edge_step_px : hint_range(4.0, 64.0) = 20.0;
uniform float edge_wobble_px : hint_range(0.0, 28.0) = 8.0;
group_uniforms;

group_uniforms impact;
uniform float impact_reach_px : hint_range(0.0, 260.0) = 120.0;
uniform float lip_jitter_px : hint_range(0.0, 32.0) = 12.0;
uniform float source_mist_strength : hint_range(0.0, 1.0) = 0.2;
uniform float impact_mist_strength : hint_range(0.0, 1.0) = 0.35;
uniform float foam_height_px : hint_range(4.0, 80.0) = 28.0;
group_uniforms;

group_uniforms motion;
uniform float anim_fps : hint_range(1.0, 20.0) = 7.0;
uniform float fall_speed_px : hint_range(10.0, 300.0) = 104.0;
uniform float ribbon_width_px : hint_range(4.0, 32.0) = 10.0;
uniform float flow_cell_px : hint_range(8.0, 80.0) = 34.0;
uniform float veil_gap_strength : hint_range(0.0, 1.0) = 0.42;
uniform float edge_drop_density : hint_range(0.0, 0.5) = 0.08;
group_uniforms;

group_uniforms palette;
uniform vec4 deep_color : source_color = vec4(0.25, 0.54, 0.57, 0.92);
uniform vec4 mid_color : source_color = vec4(0.46, 0.72, 0.71, 0.95);
uniform vec4 light_color : source_color = vec4(0.76, 0.88, 0.82, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.95, 0.86, 1.0);
uniform vec4 mist_color : source_color = vec4(0.78, 0.89, 0.83, 1.0);
uniform float body_alpha : hint_range(0.0, 1.0) = 0.84;
uniform float mist_alpha : hint_range(0.0, 1.0) = 0.18;
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 263.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	float t = floor(TIME * anim_fps) / anim_fps;
	float frame = floor(TIME * anim_fps);
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;

	float fall_span = max(bottom_y - top_y, 0.001);
	float fy = clamp((quv.y - top_y) / fall_span, 0.0, 1.0);
	float end_center = center_x + bend_px / size_px.x;
	float ribbon = floor((px.x - size_px.x * center_x) / ribbon_width_px);
	float local_top_y = top_y + (hash21(vec2(ribbon, 17.0)) - 0.5) * lip_jitter_px / size_px.y;
	float local_bottom_y = bottom_y + (hash21(vec2(ribbon, 97.0)) - 0.5) * lip_jitter_px / size_px.y;
	float in_height = step(local_top_y, quv.y) * step(quv.y, local_bottom_y);

	// 稳定而不规则的外轮廓；水体运动只发生在轮廓内部。
	float edge_row = floor(px.y / edge_step_px);
	float edge_noise = hash21(vec2(edge_row, 41.0)) - 0.5;
	float center = mix(center_x, end_center, fy) + edge_noise * edge_wobble_px / size_px.x;
	float half_width_px = mix(top_half_width_px, bottom_half_width_px, pow(fy, 0.82));
	float local_x_px = (quv.x - center) * size_px.x;
	float norm_x = abs(local_x_px) / max(half_width_px, 0.001);
	float body = step(norm_x, 1.0) * in_height;

	// 固定纵向水帘决定大色块，移动水丝只改变局部亮度和透明度。
	float column_hash = hash21(vec2(ribbon, 83.0));
	float column_hash_2 = hash21(vec2(ribbon + 29.0, 131.0));
	float fall_cell = floor((px.y - t * fall_speed_px) / flow_cell_px);
	float fall_cell_fast = floor((px.y - t * fall_speed_px * 1.45) / (flow_cell_px * 0.62));
	float flow_hash = hash21(vec2(ribbon, fall_cell));
	float flow_hash_fast = hash21(vec2(ribbon + 17.0, fall_cell_fast));

	float thin_curtain = step(0.20, column_hash);
	float pale_curtain = step(0.72, column_hash_2);
	float moving_light = step(0.68, flow_hash);
	float white_thread = step(0.87, flow_hash_fast) * step(0.52, column_hash);
	float moving_gap = step(0.94, hash21(vec2(ribbon + 43.0, fall_cell - 11.0)));

	vec3 water = deep_color.rgb;
	water = mix(water, mid_color.rgb, thin_curtain * 0.70);
	water = mix(water, light_color.rgb, pale_curtain * 0.30 + moving_light * 0.42);
	water = mix(water, foam_color.rgb, white_thread * 0.72);
	water = mix(water, deep_color.rgb, step(0.82, norm_x) * 0.42);

	float veil_alpha = mix(0.62, 1.0, column_hash);
	veil_alpha *= mix(1.0, 1.0 - veil_gap_strength, moving_gap);
	// 越接近底部越可能分成两束，避免整段像一张垂直塑料板。
	float split_width_px = mix(0.0, 9.0, smoothstep(0.58, 0.95, fy));
	float bottom_split = step(abs(local_x_px), split_width_px) * smoothstep(0.58, 0.92, fy);
	veil_alpha *= 1.0 - bottom_split * 0.52;
	float alpha = body * body_alpha * veil_alpha;

	// 顶部翻水只是一条参差的浅色边，通常会被崖口素材遮住大半。
	float lip_dist_px = abs(quv.y - local_top_y) * size_px.y;
	float lip = body * step(lip_dist_px, px_size * 1.4) * step(0.54, hash21(vec2(ribbon, frame * 0.15)));
	water = mix(water, foam_color.rgb, lip * 0.72);
	alpha = max(alpha, lip * body_alpha);

	// 轮廓外的独立水滴：沿固定细列下落，数量低、速度高。
	float drop_zone = step(1.0, norm_x) * step(norm_x, 1.30) * in_height;
	float drop_col = floor(px.x / (px_size * 2.0));
	float drop_row = floor((px.y - t * fall_speed_px * 1.35) / (px_size * 5.0));
	float drop_seed = hash21(vec2(drop_col, drop_row));
	float drop = step(1.0 - edge_drop_density, drop_seed) * drop_zone;
	water = mix(water, light_color.rgb, drop);
	alpha = max(alpha, drop * 0.58);

	// 撞击区由稳定底雾 + 换帧泡沫簇组成；保持像素颗粒，不做光滑椭圆光斑。
	vec2 impact_scale = vec2(bottom_half_width_px + impact_reach_px * 0.55, foam_height_px);
	vec2 impact_p = vec2((px.x - end_center * size_px.x) / max(impact_scale.x, 1.0),
		(px.y - bottom_y * size_px.y) / max(impact_scale.y, 1.0));
	float impact_shape = 1.0 - smoothstep(0.30, 1.0, length(impact_p));
	vec2 foam_cell = floor(px / vec2(px_size * 2.0, px_size * 1.5));
	float foam_stable = step(0.60, hash21(foam_cell + vec2(53.0, 17.0)));
	float foam_cycle = step(0.78, hash21(foam_cell + vec2(mod(frame, 6.0) * 7.0, 91.0)));
	float foam = impact_shape * max(foam_stable * 0.62, foam_cycle);
	water = mix(water, foam_color.rgb, foam * 0.82);
	alpha = max(alpha, foam * body_alpha * impact_mist_strength);

	// 源头只留稀疏水汽颗粒；不制造发光圆盘。
	vec2 source_scale = vec2(top_half_width_px + 38.0, 22.0);
	vec2 source_p = vec2((px.x - center_x * size_px.x) / source_scale.x,
		(px.y - top_y * size_px.y) / source_scale.y);
	float source_shape = 1.0 - smoothstep(0.34, 1.0, length(source_p));
	float source_dither = step(0.68, hash21(foam_cell + vec2(11.0, 37.0)));
	float source_mist = source_shape * source_dither * source_mist_strength;
	water = mix(water, mist_color.rgb, source_mist * 0.56);
	alpha = max(alpha, source_mist * mist_alpha);

	COLOR = vec4(water, clamp(alpha, 0.0, 1.0));
}
