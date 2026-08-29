shader_type canvas_item;
render_mode unshaded;

// Bubble 技能图标换装：旧图向指定对角收束，新图用同一进度反向重组。
// 材质只挂在图标 CanvasItem 上，因此按钮底色、像素描边与投影完全不参与转场。
uniform float switch_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 exit_direction = vec2(1.0, 1.0);
uniform float block_columns : hint_range(12.0, 64.0) = 36.0;
uniform float block_rows : hint_range(12.0, 64.0) = 36.0;
uniform float diagonal_bands : hint_range(4.0, 16.0) = 9.0;
uniform vec4 handoff_color : source_color = vec4(0.84, 0.64, 0.24, 1.0);
// false=保留潮线前方的旧图；true=保留潮线后方的新图。两者使用同一 cutoff，严格互补。
uniform bool reveal_behind = false;

void fragment() {
	float progress = clamp(switch_progress, 0.0, 1.0);
	if ((!reveal_behind && progress >= 0.999)
			|| (reveal_behind && progress <= 0.001)) {
		discard;
	}

	vec2 direction = vec2(
			exit_direction.x >= 0.0 ? 1.0 : -1.0,
			exit_direction.y >= 0.0 ? 1.0 : -1.0);
	vec2 grid = vec2(block_columns, block_rows);
	vec2 block_uv = (floor(UV * grid) + vec2(0.5)) / grid;
	vec2 directed_uv = vec2(
			direction.x > 0.0 ? block_uv.x : 1.0 - block_uv.x,
			direction.y > 0.0 ? block_uv.y : 1.0 - block_uv.y);
	float diagonal_axis = (directed_uv.x + directed_uv.y) * 0.5;

	// 平行于收束方向的斜带分四拍错开，像角色换人一样分层离场，而非整齐硬切。
	float perpendicular = (block_uv.x - block_uv.y + 1.0) * 0.5;
	float band = floor(perpendicular * diagonal_bands);
	float band_phase = mod(band, 4.0) / 3.0;
	float stagger = (band_phase - 0.5) * 0.050 * sin(progress * 3.14159265);
	float cutoff = clamp(progress + stagger, 0.0, 1.0);
	if (reveal_behind) {
		if (diagonal_axis > cutoff) {
			discard;
		}
	} else if (progress > 0.001 && diagonal_axis <= cutoff) {
		discard;
	}

	// 各斜带以不同幅度向目标角滑动，形成明确的“收走/重组”而不是普通擦除。
	float motion_progress = reveal_behind ? 1.0 - progress : progress;
	float travel = motion_progress * (0.010 + band_phase * 0.028);
	vec2 sample_uv = UV - direction * travel;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0
			|| sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		discard;
	}
	vec4 source = texture(TEXTURE, sample_uv) * COLOR;
	if (source.a <= 0.001) {
		discard;
	}

	float edge_width = 1.45 / min(block_columns, block_rows);
	if (progress > 0.001 && abs(diagonal_axis - cutoff) <= edge_width) {
		source.rgb = mix(source.rgb, handoff_color.rgb, handoff_color.a * 0.52);
	}
	COLOR = source;
}
