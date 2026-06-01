shader_type canvas_item;

// =============================================================
// canvas_env_meteor.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 背景层流星（全屏 alpha 层，最远天空）
//   周期性流星：每隔 period 秒、按 spawn_chance 概率出现一颗，沿 travel_dir 斜划过天空，
//   带拖尾（头亮尾淡）、整体淡入淡出。起点在天空上部随机；非流星时刻 alpha=0。
//   纯程序化、无纹理；aspect 校正保证斜线角度与线粗在屏幕上正确。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 全屏 1 pass、纯算术 → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，alpha 混合，TIME 驱动）。
// =============================================================

group_uniforms timing;
uniform float period : hint_range(2.0, 30.0) = 7.0;        // 出现间隔(秒)
uniform float duration : hint_range(0.3, 3.0) = 1.1;       // 单颗划过时长(秒)
uniform float spawn_chance : hint_range(0.0, 1.0) = 0.8;   // 每周期出现概率(<1 → 偶尔不出现)
group_uniforms;

group_uniforms shape;
uniform vec2 travel_dir = vec2(0.8, 0.45);                 // 划过方向(默认右下)
uniform float travel_len : hint_range(0.1, 1.5) = 0.6;     // 划过距离(屏幕高度比)
uniform float trail_len : hint_range(0.02, 0.4) = 0.14;    // 拖尾长度
uniform float thickness : hint_range(0.0005, 0.01) = 0.0018; // 线粗
group_uniforms;

group_uniforms look;
uniform vec4 meteor_color : source_color = vec4(0.85, 0.93, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float spawn_top : hint_range(0.0, 1.0) = 0.05;     // 起点天区上边界(UV.y)
uniform float spawn_band : hint_range(0.0, 1.0) = 0.45;    // 起点天区高度
group_uniforms;

float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
vec2 hash2(float n) { return fract(sin(vec2(n * 127.1, n * 311.7)) * 43758.5453); }

void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = vp.x / vp.y;
	vec2 dir = normalize(travel_dir);

	float cycle = floor(TIME / period);            // 当前周期索引
	float t_in = fract(TIME / period) * period;    // 周期内已过秒数

	float v = 0.0;
	if (t_in < duration && hash1(cycle + 0.5) < spawn_chance) {
		float prog = t_in / duration;              // 0..1 划过进度
		vec2 rnd = hash2(cycle * 1.7 + 3.1);
		// 起点(天空上部随机)，在 aspect 校正空间(x: 0..aspect)
		vec2 start = vec2((0.6 + rnd.x * 0.4) * aspect, spawn_top + rnd.y * spawn_band);
		vec2 head = start + dir * travel_len * prog;
		vec2 P = vec2(UV.x * aspect, UV.y);
		vec2 toP = P - head;
		float along = dot(toP, -dir);              // 沿拖尾方向(>0 = 在流星头后方)
		float perp = length(toP + dir * along);    // 到轨迹线的垂直距离
		float trail = smoothstep(thickness, 0.0, perp)
			* smoothstep(trail_len, 0.0, along) * step(0.0, along);
		float fade = sin(prog * 3.14159265);       // 淡入→淡出
		v = trail * fade;
	}
	COLOR = vec4(meteor_color.rgb, clamp(v * brightness, 0.0, 1.0));
}
