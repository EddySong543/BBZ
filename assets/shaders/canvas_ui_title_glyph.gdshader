shader_type canvas_item;

// 标题字专用着色（title_logo.gd）：王冠同源金 —— 双色调字身 + 结构性棱线 + flash 白闪 + sweep 扫光。
// 2026-06-11 1A「与王冠同金」+ 加重批（Eddy 反馈纯平涂偏淡）：
//   字身 = 上半主金 / 下半深金，一道干净硬分界（⛔渐变 ⛔色带 ⛔抖动——中低明度金上的
//   抖动读成污渍，与波流 dither 教训同根）；笔画上缘 1 字体像素亮金 'L'（受光面），
//   下缘 1 字体像素深影 'x'（落影收底）。取色全部来自王冠像素稿色板，
//   与王冠高光/波浪白浪尖共用「平涂色场 + 结构性高光 + 深描边」一套材质语法。
// 原理：Label 字身 pass 顶点色=白 → 乘金色后显出金；描边/投影 pass 顶点色为深色
//      → 乘任何亮度因子仍保持深色，因此着色只作用于字身。
// 复杂度：3 次纹理采样，无动态分支；目标平台 PC（boot 一次性场景）。

uniform float glyph_height = 120.0;  // 字面高度(px)：顶点 y 归一化 → 双色调分界参数
uniform float px_size = 10.0;        // 1 字体像素 = 多少屏幕像素（= font_size / 12，棱线粒度）
uniform float flash : hint_range(0.0, 1.0) = 0.0;  // 1=字身打白（落地闪/金光）
// 扫光（title_logo._anim_sweep 驱动·攒成形后一道光左→右掠过文字）：
uniform float sweep = -1.0;          // 扫光带中心（「标题整行」归一化 x；-1=关闭，关闭态对基础渲染零影响）
uniform float glyph_u0 = 0.0;        // 本字左缘在「标题整行」的归一化 x
uniform float glyph_u1 = 1.0;        // 本字右缘在「标题整行」的归一化 x

// 王冠色板同源（pixel_glyphs.gd CROWN_COLORS）：'L' 亮金 / '#' 主金 / 中间档 / 'x' 深影
const vec3 GOLD_LIGHT = vec3(1.000, 0.878, 0.541);    // #ffe08a
const vec3 GOLD_BODY = vec3(0.957, 0.784, 0.294);     // #f4c84b
const vec3 GOLD_BODY_LOW = vec3(0.839, 0.655, 0.239); // #d6a73d（# 与 + 的中间档·下半身）
const vec3 GOLD_DEEP = vec3(0.478, 0.333, 0.094);     // #7a5518（下缘落影）
const float SPLIT_Y = 0.52;          // 双色调分界（字面高度比例·硬切无过渡）
const float SWEEP_WIDTH = 0.16;      // 扫光带半宽（标题归一化）
const float SWEEP_SKEW = 0.18;       // 斜度（随字高偏移 → 斜向掠过，更像"光"）
const float SWEEP_STRENGTH = 0.8;    // 带内字身推向亮白的强度

varying float v_y;

void vertex() {
	v_y = VERTEX.y / glyph_height;
}

void fragment() {
	// 双色调字身：上主金 / 下深金一刀切（像素 logo 的标准两调身体，非渐变）
	vec3 body = mix(GOLD_BODY, GOLD_BODY_LOW, step(SPLIT_Y, v_y));
	// 结构性棱线（王冠语法）：笔画上缘=亮金 / 下缘=深影（上缘优先）
	vec2 off = vec2(0.0, TEXTURE_PIXEL_SIZE.y * px_size);
	float a_here = texture(TEXTURE, UV).a;
	float a_up = texture(TEXTURE, UV - off).a;
	float a_dn = texture(TEXTURE, UV + off).a;
	float top_e = step(0.5, a_here) * (1.0 - step(0.5, a_up));
	float bot_e = step(0.5, a_here) * (1.0 - step(0.5, a_dn)) * (1.0 - top_e);
	vec3 gold = mix(mix(body, GOLD_DEEP, bot_e), GOLD_LIGHT, top_e);
	vec3 lit = mix(gold, vec3(1.0), flash);            // flash 白闪（既有）
	// 扫光：标题空间一道斜向亮带左→右掠过；并入乘子 → 仅作用字身（描边/投影顶点色≈0，乘任何值仍≈0 不受影响）
	if (sweep > -0.5) {
		float tx = mix(glyph_u0, glyph_u1, UV.x) + (v_y - 0.5) * SWEEP_SKEW;
		float s = smoothstep(SWEEP_WIDTH, 0.0, abs(tx - sweep));
		lit = mix(lit, vec3(1.0), s * SWEEP_STRENGTH);
	}
	COLOR.rgb *= lit;
}
