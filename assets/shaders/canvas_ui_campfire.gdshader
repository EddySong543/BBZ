shader_type canvas_item;

// =============================================================
// canvas_ui_campfire.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 故事卡「炉火夜话」ModeCard 程序篝火母题（2026-06-24·B 路线）。
//   暗暖炉边氛围 + 噪声火舌 + 上升火星 + 暖色呼吸。零贴图，全程序生成。
//   像素语言与 wave_clash（对波卡）统一：格点量化 + Bayer 4x4 dither + levels 档位 + 像素台阶圆角自切。
//   ⚠ Godot clip_children 不执行父节点自定义 shader → 圆角必须本层自切（corner_radius/corner_grid）。
//
//   2026-06-24 二改（Eddy F6 看 res/fire.png：右侧明显竖直亮带）。根因＝去 banding 失败：
//   初版用「横向高斯光晕」，其等值线天生竖直；被 levels 量化后每条等值线成一道竖色带，
//   且背景亮度几乎只随 x 变（上半部均匀），条纹必然竖直。修：改「自底部火源的径向辉光」
//   —— 等值线变成以火源为心的【圆弧】，叠顶暗底亮的纵向衰减，从根上消除竖直结构。
// 时间驱动: mode_card.gd 每帧把 anim_time 累加 → 火焰演化 / 火星上升 / 呼吸同源派生。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 低（3-octave fbm + 少量 exp，无纹理采样）。
// 渲染管线: Godot 4.x Forward+（2D canvas_item）。
// =============================================================

uniform float aspect = 0.67;
uniform float cells_x = 54.0;
uniform int levels : hint_range(8, 96) = 40;
uniform float dither_amt : hint_range(0.0, 2.0) = 1.0;
uniform float anim_time = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;
uniform float corner_grid : hint_range(12.0, 200.0) = 88.0;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

// 暖色 ramp（炉火）：暗暖炉边底 → 深红炭 → 橙 → 金黄 → 暖白焰心
vec3 fire_color_at(float L) {
	vec3 c0 = vec3(0.09, 0.050, 0.040);
	vec3 c1 = vec3(0.45, 0.13, 0.06);
	vec3 c2 = vec3(0.85, 0.34, 0.10);
	vec3 c3 = vec3(1.00, 0.66, 0.22);
	vec3 c4 = vec3(1.00, 0.92, 0.62);
	vec3 cW = vec3(1.00, 0.99, 0.90);
	if (L < 0.20) return mix(c0, c1, L / 0.20);
	if (L < 0.45) return mix(c1, c2, (L - 0.20) / 0.25);
	if (L < 0.68) return mix(c2, c3, (L - 0.45) / 0.23);
	if (L < 0.85) return mix(c3, c4, (L - 0.68) / 0.17);
	return mix(c4, cW, min((L - 0.85) / 0.15, 1.0));
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(UV * grid);
	vec2 cuv = (ci + 0.5) / grid;

	float breath = 0.86 + 0.14 * sin(anim_time * 1.1);
	// 火舌噪声：向【上】窜（+anim_time → 特征上移＝火往上）。仅用于火焰本体，不污染背景辉光。
	// 时间系数放慢（1.5→0.8）→ 火焰窜动更沉稳。
	float nf = fbm(vec2(cuv.x * 4.0, cuv.y * 4.0 + anim_time * 0.8));
	// 背景辉光用【静态】有机纹理（不含 anim_time → 不产生下滑斑块）。
	float ns = fbm(vec2(cuv.x * 3.0, cuv.y * 3.0));

	// 1) 自底部火源的径向辉光（等值线＝以火源为心的【圆弧】，非竖直 → 根除竖直条纹）。
	//    cuv.y 越小（越靠卡顶）→ 到火源越远 → 越暗，天然顶暗底亮、上半不再均匀。
	//    ⚠ 只随 breath 整体呼吸 + 静态轻纹理，稳定不滑（上轮辉光被会动的噪声调制 → 下滑长方形）。
	vec2 d = vec2((cuv.x - 0.5) * aspect, cuv.y - 1.04);
	float rdist = length(d);
	float glow = exp(-rdist * rdist * 2.7) * (0.90 + 0.12 * ns) * breath;

	// 2) 火焰锥形主体（底宽顶窄，火舌噪声驱动向上窜）
	float h = clamp(1.0 - cuv.y, 0.0, 1.0);
	float flame_h = 0.46;
	float local_h = (1.0 - cuv.y) / flame_h;
	float half_w = (0.19 * (1.0 - local_h * 0.85)) * (0.70 + nf * 0.70);
	float core = 1.0 - smoothstep(0.0, max(half_w, 0.001), abs(cuv.x - 0.5) * aspect);
	float env = smoothstep(0.0, 0.10, h) * (1.0 - smoothstep(flame_h * 0.55, flame_h, h));
	float flame = core * env * (0.85 + nf * 0.5) * breath;

	// 3) 上升火星：4 个【细小】点（系数 320 = 真小，避免被 aspect 拉成大光球），
	//    活动范围压在火焰上方（sy 不飘到卡顶 → 不在左上结团），亮度调淡。
	float spark = 0.0;
	for (int s = 0; s < 4; s++) {
		float fs = float(s);
		float sh = hash21(vec2(fs * 7.3, 2.0));
		float sh2 = hash21(vec2(fs * 3.1, 9.0));
		float rise = fract(sh + anim_time * (0.10 + sh2 * 0.07));
		float sy = mix(0.92, 0.34, rise);
		float sx = 0.5 + (sh - 0.5) * 0.42 + sin(anim_time * 1.1 + sh * 30.0) * 0.04;
		vec2 sd = vec2((cuv.x - sx) * aspect, cuv.y - sy);
		float tw = 0.5 + 0.5 * sin(anim_time * 4.0 + sh * 50.0);
		float sf = smoothstep(0.0, 0.12, rise) * (1.0 - smoothstep(0.55, 1.0, rise));
		spark = max(spark, exp(-dot(sd, sd) * 320.0) * tw * sf * 0.5);
	}

	// 合成亮度 + 有机抖动（fbm 各向同性噪声打散低频渐变的方向性）
	float L = glow + flame + spark;
	L += (fbm(vec2(cuv.x * 11.0, cuv.y * 11.0)) - 0.5) * 0.04;
	L = clamp(L * intensity, 0.0, 0.9999);

	// Bayer + 白噪声 dither + 档位量化（白噪声破掉 Bayer 规整骨架）
	int bx = int(mod(ci.x, 4.0));
	int by = int(mod(ci.y, 4.0));
	float dith = (BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5;
	dith += (hash21(ci + vec2(0.7, 1.3)) - 0.5);
	L = clamp(L + dith * dither_amt / float(levels), 0.0, 0.9999);
	L = floor(L * float(levels)) / float(levels);

	vec3 col = fire_color_at(L);

	float a = 1.0;
	if (corner_radius > 0.0) {
		vec2 q = (floor(UV * corner_grid) + vec2(0.5)) / corner_grid;
		vec2 cc = vec2(min(q.x, 1.0 - q.x) * aspect, min(q.y, 1.0 - q.y));
		vec2 cv = vec2(corner_radius) - cc;
		if (cv.x > 0.0 && cv.y > 0.0 && length(cv) > corner_radius) {
			a = 0.0;
		}
	}
	COLOR = vec4(col, a);
}
