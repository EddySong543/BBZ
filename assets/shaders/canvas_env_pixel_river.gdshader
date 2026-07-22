shader_type canvas_item;

// =============================================================
// Scene2 近景河流：分层水平切片倒影。
// 设计重点不是连续液化，而是以远细近粗的像素行拼出透视：每条水带拥有稳定的
// 色值、横移速度和相位，倒影被切成可读的水平块；稀疏水线沿各自深度横移。
// 节点之前绘制的山、瀑布、岸台会进入倒影，角色保持不反射。
// =============================================================

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

group_uniforms layout;
uniform vec2 size_px = vec2(2016.0, 205.0);
uniform vec2 screen_px = vec2(1920.0, 1080.0);
uniform float px_size : hint_range(1.0, 8.0) = 3.0;
group_uniforms;

group_uniforms reflection;
uniform float stretch : hint_range(0.5, 3.5) = 2.15;
uniform float refl_strength : hint_range(0.0, 1.0) = 0.68;
uniform float refl_levels : hint_range(2.0, 16.0) = 7.0;
uniform float slice_px_far : hint_range(1.0, 10.0) = 3.0;
uniform float slice_px_near : hint_range(2.0, 16.0) = 8.0;
uniform float slice_shift_px : hint_range(0.0, 30.0) = 12.0;
uniform float slice_speed : hint_range(0.0, 2.0) = 0.24;
uniform float breakup_px : hint_range(8.0, 128.0) = 54.0;
uniform float breakup_strength : hint_range(0.0, 1.0) = 0.34;
group_uniforms;

group_uniforms water;
uniform vec4 surface_color : source_color = vec4(0.24, 0.43, 0.43, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.13, 0.29, 0.31, 1.0);
uniform vec4 deep_color : source_color = vec4(0.035, 0.09, 0.12, 1.0);
uniform float depth_curve : hint_range(0.2, 4.0) = 1.25;
uniform float row_contrast : hint_range(0.0, 0.3) = 0.09;
group_uniforms;

group_uniforms ripple;
uniform float anim_fps : hint_range(1.0, 20.0) = 8.0;
uniform float ripple_speed_px : hint_range(-80.0, 80.0) = 20.0;
uniform float ripple_density : hint_range(0.0, 0.8) = 0.23;
uniform vec4 ripple_color : source_color = vec4(0.54, 0.72, 0.66, 1.0);
uniform float glint_density : hint_range(0.0, 0.4) = 0.065;
uniform vec4 glint_color : source_color = vec4(0.96, 0.92, 0.76, 1.0);
group_uniforms;

group_uniforms shore;
uniform vec4 shore_dark : source_color = vec4(0.055, 0.13, 0.14, 1.0);
uniform vec4 shore_light : source_color = vec4(0.55, 0.72, 0.63, 1.0);
uniform float shore_px : hint_range(1.0, 8.0) = 3.0;
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(511.0, 257.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	float t = floor(TIME * anim_fps) / anim_fps;
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;
	float depth = pow(quv.y, depth_curve);

	// 远处水带细、近处水带粗；整条水带共用一个镜像采样高度和水平位移。
	float band_h = mix(slice_px_far, slice_px_near, depth);
	float band_id = floor(px.y / band_h);
	float band_y = (band_id + 0.5) * band_h;
	float band_depth = clamp(band_y / size_px.y, 0.0, 1.0);
	float band_phase = hash21(vec2(band_id, 17.0)) * 6.2831853;
	float band_shift = sin(t * slice_speed * 6.2831853 * (0.55 + band_depth) + band_phase);
	band_shift = floor(band_shift * slice_shift_px / px_size) * px_size;

	// 大块水平断裂只做低幅叠加，保持树和瀑布的竖向倒影仍然可读。
	float block_w = mix(breakup_px * 0.65, breakup_px * 1.45, band_depth);
	float block_id = floor(px.x / block_w);
	float block_phase = hash21(vec2(block_id, band_id + 31.0)) - 0.5;
	float block_shift = floor(block_phase * slice_shift_px * breakup_strength / px_size) * px_size;

	vec2 suv = SCREEN_UV + (quv - UV) * size_px / screen_px;
	float waterline = suv.y - quv.y * size_px.y / screen_px.y;
	float reflected_depth_px = band_y * stretch;
	vec2 ruv = vec2(
		suv.x + (band_shift + block_shift) / screen_px.x,
		waterline - reflected_depth_px / screen_px.y);
	ruv.y = clamp(ruv.y, 0.001, max(waterline - 0.001, 0.001));
	vec3 refl = texture(screen_tex, ruv).rgb;
	refl = floor(refl * refl_levels + 0.5) / refl_levels;

	// 每条水带拥有稳定明暗，形成 Cast n Chill / Kingdom 类水面的横向层次，而非噪点。
	float row_value = hash21(vec2(band_id, 73.0));
	float row_tone = mix(1.0 - row_contrast, 1.0 + row_contrast, row_value);
	vec3 water_base = mix(surface_color.rgb, shallow_color.rgb, smoothstep(0.0, 0.38, depth));
	water_base = mix(water_base, deep_color.rgb, smoothstep(0.34, 1.0, depth));
	water_base *= row_tone;
	float refl_mix = refl_strength * (1.0 - 0.58 * depth);
	vec3 col = mix(water_base, refl * mix(1.02, 0.72, depth), refl_mix);

	// 水线是成组横向短线：随深度变长、变稀，并以不同速度横移，持续多帧。
	float ripple_row_h = mix(6.0, 12.0, depth);
	float ripple_row = floor(px.y / ripple_row_h);
	float drift = t * ripple_speed_px * mix(0.45, 1.0, depth);
	float cell_w = mix(34.0, 82.0, depth);
	float shifted_x = px.x + drift + hash21(vec2(ripple_row, 29.0)) * cell_w;
	float ripple_cell = floor(shifted_x / cell_w);
	float ripple_local = mod(shifted_x, cell_w);
	float ripple_hash = hash21(vec2(ripple_cell, ripple_row));
	float ripple_len = mix(7.0, cell_w * 0.58, hash21(vec2(ripple_cell + 13.0, ripple_row)));
	float ripple_active = step(1.0 - ripple_density, ripple_hash) * step(ripple_local, ripple_len);
	float ripple_line = step(mod(px.y, ripple_row_h), px_size) * ripple_active;
	float ripple_fade = smoothstep(0.03, 0.14, quv.y) * (1.0 - smoothstep(0.72, 1.0, quv.y));
	col = mix(col, ripple_color.rgb, ripple_line * ripple_fade * 0.46);

	// 金白高光只占少量长线中的一部分，不再全屏随机闪烁。
	float glint_active = step(1.0 - glint_density, hash21(vec2(ripple_cell + 47.0, ripple_row + floor(t * 0.5))));
	float glint = ripple_line * glint_active * smoothstep(0.04, 0.18, quv.y) * (1.0 - smoothstep(0.48, 0.78, quv.y));
	col = mix(col, glint_color.rgb, glint * 0.82);

	// 岸边先暗后亮：比一整条白色泡沫线更像静水贴岸。
	float shore_dark_mask = 1.0 - step((shore_px + px_size) / size_px.y, quv.y);
	float shore_light_mask = 1.0 - step(shore_px / size_px.y, quv.y);
	col = mix(col, shore_dark.rgb, shore_dark_mask * 0.72);
	col = mix(col, shore_light.rgb, shore_light_mask * 0.62);

	COLOR = vec4(col, 1.0);
}
