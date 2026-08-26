shader_type canvas_item;
render_mode unshaded;

// 换人专用：规则横向像素带向己方边缘收束，反向播放即为新英雄重组。
// 与死亡侵蚀明确区分：无随机噪声、无轮廓向内瓦解、无灰黑死亡前沿。
uniform float switch_progress : hint_range(0.0, 1.0) = 0.0;
uniform float outward_right : hint_range(0.0, 1.0) = 0.0;
uniform float switch_steps : hint_range(4.0, 16.0) = 8.0;
uniform float band_rows : hint_range(6.0, 20.0) = 12.0;
uniform float block_columns : hint_range(32.0, 128.0) = 72.0;
uniform float block_rows : hint_range(32.0, 128.0) = 72.0;
uniform vec4 handoff_color : source_color = vec4(0.50, 0.88, 0.78, 0.82);

void fragment() {
	float steps = max(switch_steps, 1.0);
	float progress = floor(clamp(switch_progress, 0.0, 1.0) * steps + 0.0001) / steps;
	float band = floor(UV.y * band_rows);
	float band_phase = mod(band, 4.0) / 3.0;
	float direction = mix(-1.0, 1.0, outward_right);

	// 每条横向像素带以固定次序错开，形成稳定可读的传送节拍，而不是随机瓦解。
	float band_shift = progress * (0.035 + band_phase * 0.035);
	vec2 sample_uv = UV;
	sample_uv.x -= direction * band_shift;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0) {
		discard;
	}
	vec2 grid = vec2(block_columns, block_rows);
	sample_uv = (floor(sample_uv * grid) + vec2(0.5)) / grid;
	vec4 source = texture(TEXTURE, sample_uv);

	// 从战场中心一侧逐带收向己方边缘；progress=1 时所有带完全离场。
	float distance_from_outward_edge = mix(UV.x, 1.0 - UV.x, outward_right);
	float band_stagger = band_phase * 0.012;
	float visible_limit = 1.02 - progress * 1.18 + band_stagger;
	if (distance_from_outward_edge > visible_limit) {
		discard;
	}

	// 只在规则切换边留一格青绿交接光；不沿人物轮廓生成死亡前沿。
	float handoff_width = 1.35 / block_columns;
	if (switch_progress > 0.0001
			&& abs(distance_from_outward_edge - visible_limit) <= handoff_width) {
		source.rgb = mix(source.rgb, handoff_color.rgb, handoff_color.a);
	}
	COLOR = source * COLOR;
}
