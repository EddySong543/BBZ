// HD-2D 原型：程序化像素石材（地面/立柱/平台共用，无贴图）
// 世界坐标按主轴投影 → 量化到虚拟像素格 → 砖块 hash 色差 + 砖缝压暗 + 色阶化
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.16, 0.17, 0.22);
uniform float tile_size = 0.9;
uniform float px_per_meter = 16.0;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.85;
uniform float color_jitter : hint_range(0.0, 1.0) = 0.35;
uniform float groove_dark : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 an = abs(v_wnrm);
	vec2 uv;
	if (an.y > an.x && an.y > an.z) {
		uv = v_wpos.xz;
	} else if (an.x > an.z) {
		uv = v_wpos.zy;
	} else {
		uv = v_wpos.xy;
	}
	uv = floor(uv * px_per_meter) / px_per_meter;  // 虚拟像素格

	vec2 tid = floor(uv / tile_size);
	vec2 tuv = fract(uv / tile_size);
	float h = hash2(tid);
	float edge = min(min(tuv.x, 1.0 - tuv.x), min(tuv.y, 1.0 - tuv.y));
	float groove = mix(1.0 - groove_dark, 1.0, step(0.05, edge));

	vec3 col = base_color * (1.0 - color_jitter * 0.5 + color_jitter * h) * groove;
	col = floor(col * 14.0) / 14.0;  // 色阶化贴像素风
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	SPECULAR = 0.15;
}
