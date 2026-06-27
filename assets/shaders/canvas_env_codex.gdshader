shader_type canvas_item;

// =============================================================
// canvas_env_codex.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 图鉴「书房典籍」背景 —— 暖墨胡桃竖向渐变 + 极淡纸纹 + 暗角。
//   取代旧蓝色水波(canvas_env_wave_flow)做图鉴底。静态(无 TIME)→ 计算极廉、观感安定，
//   让英雄/道具内容与暖金框跳出。蓝色普通卡贴在暖暗底上不再「蓝叠蓝」。
//   纸纹仅「提亮」不压暗(避免中低明度区脏成污渍)，并向底部淡出。posterize+dither 杀 banding。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 1 个 hash、无纹理采样 → 极低。
// 渲染管线: Godot 4.7 Forward+（2D canvas_item）。
// =============================================================

group_uniforms palette;
uniform vec3 top_color : source_color = vec3(0.155, 0.118, 0.085);   // 顶=灯下暖胡桃
uniform vec3 bottom_color : source_color = vec3(0.072, 0.056, 0.045); // 底=深墨褐
uniform vec3 corner_color : source_color = vec3(0.040, 0.032, 0.028); // 四角暗角压到近黑暖
group_uniforms;

group_uniforms shape;
uniform float aspect : hint_range(0.1, 10.0) = 1.777;        // 宽/高比：暗角按等圆修正
uniform float vignette : hint_range(0.0, 1.0) = 0.85;        // 暗角强度(向 corner_color 收)
uniform float vignette_radius : hint_range(0.2, 1.5) = 0.62; // 暗角起始半径(越小角越早压暗)
uniform float grain_amt : hint_range(0.0, 0.12) = 0.030;     // 纸纹强度(仅提亮)
uniform float grain_px : hint_range(80.0, 1200.0) = 540.0;   // 纸纹颗粒密度(格数)
uniform float levels : hint_range(8.0, 96.0) = 48.0;         // 阶调台阶(像素风)
uniform float dither_amt : hint_range(0.0, 1.5) = 1.0;       // 抖动杀 banding
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	// ① 竖向暖渐变（顶亮底暗）
	vec3 col = mix(top_color, bottom_color, clamp(UV.y, 0.0, 1.0));

	// ② 暗角：以屏中心等圆距离向 corner_color 收（x 乘 aspect 防椭圆）
	vec2 c = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float vd = length(c) / (vignette_radius * sqrt(0.25 * aspect * aspect + 0.25));
	float vmask = clamp((vd - 1.0) * 1.6, 0.0, 1.0);        // 0=中心 1=远角
	col = mix(col, corner_color, vmask * vignette);

	// ③ 纸纹：coarse hash 颗粒，仅提亮(避免压暗成污渍)，向底部淡出
	float g = hash(floor(UV * vec2(grain_px * aspect, grain_px)));
	float fade = mix(1.0, 0.35, clamp(UV.y, 0.0, 1.0));    // 上多下少
	col += max(g - 0.5, 0.0) * grain_amt * fade;

	// ④ posterize + dither（像素阶调 + 杀 banding）
	float dpat = (hash(floor(FRAGCOORD.xy)) - 0.5) * dither_amt / levels;
	col = floor(col * levels + 0.5 + dpat) / levels;

	COLOR = vec4(col, 1.0);
}
