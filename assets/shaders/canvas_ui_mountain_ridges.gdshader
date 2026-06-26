shader_type canvas_item;

// =============================================================
// canvas_ui_mountain_ridges.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 远征卡「登天关」ModeCard 程序山脊母题（2026-06-24·B 路线）。
//   多层山脊剪影（远浅近深）+ 横向视差 + 装饰（天体/散星/地平线辉光/云海/山脊受光）。零贴图全程序生成。
//   ── 冷暖双版（warm uniform，由 mode_card 据背景胜方色绑定）──
//     warm=0 冷夜版：深蓝紫夜空 + 明月 + 散星 + 月光冷云 —— 配【蓝色】对波背景。
//     warm=1 暖日版：暖金黎明天 + 暖阳 + 无星 + 暖金云 ——     配【红色】对波背景。
//   像素语言与 wave_clash（对波卡）统一：格点量化 + Bayer 4x4 dither + 像素台阶圆角自切。
//   ⚠ Godot clip_children 不执行父节点自定义 shader → 圆角必须本层自切（corner_radius/corner_grid）。
//   片元无动态分支：山脊覆盖用 step()/mix()（4 层固定循环）。
// 时间驱动: mode_card.gd 每帧把 anim_time 累加 → 各层视差横移（近快远慢）+ 云气漂移 + 星辰闪烁。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 低（每层几条 sin 叠加，无纹理采样）。
// 渲染管线: Godot 4.x Forward+（2D canvas_item）。
// =============================================================

uniform float aspect = 0.67;
uniform float cells_x = 54.0;
uniform int levels : hint_range(8, 96) = 32;
uniform float dither_amt : hint_range(0.0, 2.0) = 1.0;
uniform float anim_time = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float warm : hint_range(0.0, 1.0) = 0.0;     // 0=冷夜(蓝背景) / 1=暖日(红背景)

uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;
uniform float corner_grid : hint_range(12.0, 200.0) = 88.0;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0);

float hash11(float x) { return fract(sin(x * 127.1) * 43758.5453); }

// 第 layer 层山脊在横坐标 x 处的「地平线高度」（0..1，越小越靠卡顶）。
// 多正弦叠加（不同频率/相位/振幅）→ 起伏山脊轮廓；seed 让每层错开；scroll 做视差横移。
float ridge_line(float x, float seed, float base, float amp, float scroll, float xf) {
	float xx = (x + scroll) * xf;
	float h = sin(xx * 3.1 + seed * 6.28) * 0.55
			+ sin(xx * 6.7 + seed * 2.13) * 0.28
			+ sin(xx * 13.0 + seed * 4.70) * 0.14;   // 原始圆润起伏（不加高频碎脊·保留竖卡圆润感）
	return base - amp * (h * 0.5 + 0.5);
}

void fragment() {
	vec2 grid = vec2(cells_x, cells_x / aspect);
	vec2 ci = floor(UV * grid);
	vec2 cuv = (ci + 0.5) / grid;
	// 横向特征频率随宽高比缩放（卡变宽 → 等比加密山脊/云带，防横向拉伸）。0.67 = 母题调校基准 aspect。
	float xf = aspect / 0.67;

	// 天空渐变（顶 → 地平线）。冷夜：深蓝紫→亮冷青；暖日：暖紫红高空→金黄地平。
	float sky_t = smoothstep(0.0, 0.92, cuv.y);
	vec3 sky_top = mix(vec3(0.13, 0.16, 0.32), vec3(0.33, 0.20, 0.24), warm);
	vec3 sky_low = mix(vec3(0.46, 0.54, 0.66), vec3(0.96, 0.68, 0.40), warm);
	vec3 col = mix(sky_top, sky_low, sky_t);

	// 地平线辉光（冷夜暖微曦 / 暖日强金光）——冷暖对比，去灰关键
	float hd = cuv.y - 0.34;
	vec3 hcol = mix(vec3(0.26, 0.18, 0.12), vec3(0.58, 0.34, 0.14), warm);
	col += hcol * exp(-hd * hd * 22.0) * mix(0.35, 0.55, warm);

	// 天体（右上）：冷夜＝冷白明月 / 暖日＝暖金太阳。
	// ⚠ snap 月心到像素格中心 → 干净对称圆盘（消除 Eddy 看到的「下方/右方各一碎亮点」根因）。
	vec2 sun = (floor(vec2(0.70, 0.17) * grid) + 0.5) / grid;
	float md = length(vec2((cuv.x - sun.x) * aspect, cuv.y - sun.y));
	// 月晕参考白天太阳的大柔光晕（明显可见）。冷夜=冷蓝白大晕，暖日=暖金大晕（falloff/强度对齐太阳档）。
	vec3 glow_c = mix(vec3(0.66, 0.78, 0.96), vec3(1.00, 0.78, 0.42), warm);
	col += glow_c * exp(-md * md * mix(30.0, 32.0, warm)) * mix(0.80, 0.80, warm);
	// 盘身：柔和淡银白（非纯白·纯白方块太刺眼出戏）+ 硬边干净盘（边缘不被 dither 打碎）。
	vec3 body_c = mix(vec3(0.82, 0.87, 0.95), vec3(1.00, 0.92, 0.60), warm);
	col = mix(col, body_c, step(md, 0.052));

	// 散星（仅冷夜）：【闪现星】——挂机时每颗星各按自己的周期，在一个随机位置亮起→淡出→消失，
	// 下个周期换到【新随机位置】重现（随机的是每次出现的位置，不是开局铺好原地闪）。
	// ⚠ 位置 snap 到像素格中心 → 每颗恒为 1 像素、大小绝对一致；不 snap 时星 <1 像素，
	//   落点相对格的偏差会让它忽大忽小（Eddy 看到的「一颗星大小改变」根因）。
	float stars = 0.0;
	for (int k = 0; k < 18; k++) {
		float fk = float(k);
		float period = 16.0 + hash11(fk * 1.7) * 16.0;           // 每颗周期 16~32s（大幅放慢生成）
		float cyc = anim_time / period + hash11(fk * 3.1) * 10.0;
		float seg = floor(cyc);                                  // 第几次出现（变→换位置）
		float t = fract(cyc);                                    // 本周期进度 0..1
		vec2 pos = vec2(0.06 + hash11(seg * 1.7 + fk * 13.0) * 0.88,
						0.04 + hash11(seg * 2.3 + fk * 5.0) * 0.34);
		vec2 pos_snapped = (floor(pos * grid) + 0.5) / grid;     // 对齐像素格中心 → 大小恒定
		// 可见窗口仅占周期 ~18%（亮起→峰→淡出，之后长时间空窗）→ 同时在场仅 ~3 颗
		float life = smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.10, 0.18, t));
		life *= 0.82 + 0.18 * sin(anim_time * 0.8 + fk * 7.0);   // 大幅放缓微颤（2.5→0.8）
		vec2 sd = vec2((cuv.x - pos_snapped.x) * aspect, cuv.y - pos_snapped.y);
		stars += exp(-dot(sd, sd) * 40000.0) * life;             // snap + 大系数 = 锐利单格星
	}
	col += vec3(0.85, 0.90, 1.00) * clamp(stars, 0.0, 1.0) * (1.0 - warm);

	// 4 层山脊：i 越大越近（更暗、更靠下、更崎岖、视差更快）。后画近层覆盖前层。
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float seed = fi * 1.37 + 0.5;
		float base = 0.34 + fi * 0.165;
		float amp = 0.10 + fi * 0.05;   // 原始振幅（圆润起伏·只靠 xf 去拉伸，不加陡峭）
		float scroll = anim_time * (0.010 + fi * 0.012);
		float hl = ridge_line(cuv.x, seed, base, amp, scroll, xf);
		float inside = step(hl, cuv.y);
		// 远浅 → 近深。冷夜＝冷蓝→蓝紫；暖日＝暖褐金→深暖褐
		vec3 far_c = mix(vec3(0.42, 0.52, 0.68), vec3(0.62, 0.46, 0.32), warm);
		vec3 near_c = mix(vec3(0.11, 0.13, 0.26), vec3(0.22, 0.13, 0.12), warm);
		vec3 mtn = mix(far_c, near_c, fi / 3.0);
		float rim = smoothstep(hl + 0.05, hl, cuv.y);      // 脊线正下方亮（受光）
		float depth = smoothstep(hl, hl + 0.22, cuv.y);
		mtn *= mix(1.0, 0.78, depth);
		vec3 rim_c = mix(vec3(0.30, 0.36, 0.42), vec3(0.58, 0.42, 0.26), warm);
		mtn += rim_c * rim * (1.0 - fi / 5.0);
		col = mix(col, mtn, inside);
	}

	// 云海（两条横向云带漂移）：冷夜月光冷白 / 暖日暖金
	float cd1 = (cuv.y - (0.50 + 0.02 * sin(anim_time * 0.30))) * 7.0;
	float c1 = exp(-cd1 * cd1) * (0.5 + 0.5 * sin(cuv.x * 4.0 * xf + anim_time * 0.35));
	float cd2 = (cuv.y - (0.64 + 0.025 * sin(anim_time * 0.22 + 1.5))) * 9.0;
	float c2 = exp(-cd2 * cd2) * (0.5 + 0.5 * sin(cuv.x * 6.0 * xf - anim_time * 0.30 + 2.0));
	vec3 cloud_c = mix(vec3(0.62, 0.68, 0.78), vec3(0.92, 0.74, 0.54), warm);
	col = mix(col, cloud_c, clamp(c1 * 0.22 + c2 * 0.18, 0.0, 0.34));

	// 微颗粒
	col += vec3(hash11(ci.x * 7.0 + ci.y * 13.0) - 0.5) * 0.02;

	// Bayer + 白噪声 dither + 量化（白噪声破掉 Bayer 规整骨架，天空大渐变区不现条纹）
	int bx = int(mod(ci.x, 4.0));
	int by = int(mod(ci.y, 4.0));
	float dith = ((BAYER[by * 4 + bx] + 0.5) / 16.0 - 0.5
			+ (hash11(ci.x * 3.0 + ci.y * 7.0) - 0.5)) * dither_amt / float(levels);
	col = clamp(col + vec3(dith), vec3(0.0), vec3(0.9999));
	col = floor(col * float(levels)) / float(levels);
	col *= intensity;

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
