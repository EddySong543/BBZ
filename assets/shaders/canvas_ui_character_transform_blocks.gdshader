shader_type canvas_item;
render_mode unshaded;

// 烛阴转变：黑色像素从下到上覆盖旧立绘；中点换装后，再从下到上显露新立绘。
uniform float transform_progress : hint_range(0.0, 1.0) = 0.0;
uniform float block_columns : hint_range(24.0, 128.0) = 64.0;
uniform float block_rows : hint_range(24.0, 128.0) = 72.0;
uniform vec4 transform_ink : source_color = vec4(0.015, 0.012, 0.018, 1.0);

void fragment() {
	vec2 grid = vec2(block_columns, block_rows);
	vec2 pixel_uv = (floor(UV * grid) + vec2(0.5)) / grid;
	vec4 source = texture(TEXTURE, pixel_uv) * COLOR;
	if (source.a <= 0.001) {
		discard;
	}

	float phase = clamp(transform_progress, 0.0, 1.0);
	float cell_x = floor(UV.x * grid.x);
	float cell_y = floor(UV.y * grid.y);
	// 将同一横排拆成七个确定性子相位，避免整排像素在同一帧一起跳变。
	float frontier_phase = mod(cell_x * 3.0 + cell_y * 5.0, 7.0) / 6.0;
	float stagger = (frontier_phase - 0.5) * (1.5 / grid.y);
	float boundary;
	bool inked;
	if (phase <= 0.5) {
		boundary = 1.0 - phase * 2.0 + stagger;
		inked = UV.y >= boundary;
	} else {
		boundary = 1.0 - (phase - 0.5) * 2.0 + stagger;
		inked = UV.y < boundary;
	}
	COLOR = inked ? vec4(transform_ink.rgb, source.a) : source;
}
