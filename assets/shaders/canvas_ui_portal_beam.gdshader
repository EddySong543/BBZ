shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 beam_color : source_color = vec4(1.0, 0.77, 0.31, 1.0);
uniform float beam_phase : hint_range(0.0, 1.0) = 0.0;
uniform float base_top_uv : hint_range(0.0, 1.0) = 0.58;
uniform float beam_aspect = 0.44;
uniform float anim_time = 0.0;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float fbm(vec2 point) {
	float value = 0.0;
	float weight = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		value += value_noise(point) * weight;
		point = point * 2.03 + vec2(7.1, 3.7);
		weight *= 0.48;
	}
	return value;
}


void fragment() {
	// 量化采样保留像素游戏边缘，但噪声随纵向长度增加采样密度。
	vec2 pixel_uv = floor(UV * vec2(176.0, 384.0)) / vec2(176.0, 384.0);
	float centered_x = abs(pixel_uv.x - 0.5) * 2.0;
	float anticipation = smoothstep(0.0, 0.22, beam_phase);
	float eruption = smoothstep(0.20, 0.64, beam_phase);
	float sustain = smoothstep(0.58, 0.90, beam_phase);
	float peak = smoothstep(0.90, 1.0, beam_phase);

	// 两层上行噪声共用流向但速度不同，避免纯色矩形或规则扫描条。
	float slow_noise = fbm(vec2(
			(pixel_uv.x - 0.5) * 5.5,
			pixel_uv.y * 8.0 - anim_time * 1.35));
	float fast_noise = fbm(vec2(
			(pixel_uv.x - 0.5) * 11.0 + 8.0,
			pixel_uv.y * 17.0 - anim_time * 3.1));
	float edge = 0.78 + (slow_noise - 0.5) * 0.25;
	float column = 1.0 - smoothstep(edge - 0.10, edge + 0.08, centered_x);
	float core = 1.0 - smoothstep(0.08, 0.42, centered_x);

	// 喷涌前沿由九格阵面突破到屏幕上边界；节点本身已经延伸到屏幕顶部。
	float front_y = mix(base_top_uv + 0.30, -0.10, eruption);
	float front_noise = (slow_noise - 0.5) * 0.10;
	float revealed = smoothstep(front_y - 0.045 + front_noise,
			front_y + 0.075 + front_noise, pixel_uv.y);
	float upward_strands = smoothstep(0.42, 0.86,
			fast_noise + core * 0.30
			+ sin(pixel_uv.y * 52.0 - anim_time * 8.0) * 0.08);
	float live_flicker = 0.82 + 0.12 * sin(anim_time * 9.3 + slow_noise * 6.0)
			+ 0.06 * sin(anim_time * 17.7 + pixel_uv.y * 19.0);

	// 九格底座只决定喷涌源面，不再裁切柱体高度。
	float base_half_height = max((1.0 - base_top_uv) * 0.5, 0.001);
	vec2 base_delta = vec2(
			(pixel_uv.x - 0.5) / 0.50,
			(pixel_uv.y - (base_top_uv + 1.0) * 0.5) / base_half_height);
	float base_disc = 1.0 - smoothstep(0.58, 1.02,
			length(base_delta * vec2(1.0, max(beam_aspect, 0.25))));
	float base_ring = 1.0 - smoothstep(0.025, 0.11, abs(length(base_delta) - 0.74));
	float base_energy = (base_disc * (0.24 + slow_noise * 0.30) + base_ring * 0.50)
			* anticipation;

	float column_energy = revealed * column * eruption * live_flicker
			* (0.36 + core * 0.58 + upward_strands * (0.20 + sustain * 0.34));
	float alpha = clamp(base_energy + column_energy + peak * core * revealed * 0.42,
			0.0, 0.96);
	vec3 color = mix(beam_color.rgb, vec3(1.0),
			core * (0.30 + sustain * 0.20) + peak * 0.48);
	COLOR = vec4(color * (0.82 + column_energy * 0.85 + peak * 0.60),
			alpha * beam_color.a);
}
