shader_type canvas_item;

// =============================================================
// canvas_ui_item_cell_bg.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 道具格底——圆角裁切 + 稀有度深底 + (仅传说)铺满祥云背景。
//   云纹 = 流动云气线 + 对角涡卷云头，tone-on-tone（金压深金底·参 ref14），随 TIME 极缓漂移。
//   一个材质把「圆角 / 底色 / 云纹」一起裁好 → 云纹自然不出方角、铺满整格、在道具美术之下。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 低。渲染管线: Godot 4.7 Forward+（2D canvas_item）。
// =============================================================

group_uniforms palette;
uniform vec4 fill_color : source_color = vec4(0.20, 0.10, 0.08, 1.0); // 稀有度深底（=外框色深调）
uniform vec4 cloud_color : source_color = vec4(0.97, 0.84, 0.50, 1.0); // 云纹金
uniform float fill_opaque : hint_range(0.0, 1.0) = 1.0; // 1=实底(图鉴) / 0=仅云纹叠加层(战斗·覆在 jelly 芯片上)
uniform sampler2D bg_tex : source_color, filter_linear_mipmap; // 传说背景美术图(gold_bottom)·use_tex=1 启用
uniform float use_tex = 0.0;                            // 0=程序底色+云纹 / 1=采样 bg_tex 当格底(传说·替代程序云纹)
uniform vec4 tex_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // 纹理压暗去饱和(与暗格协调不出戏)
uniform float tex_top_darkening : hint_range(0.0, 0.4, 0.01) = 0.0; // 保留原贴图，只从顶部向中部轻压明度
group_uniforms cloud;
uniform float cloud_on = 0.0;                          // 0=无云纹（普通/稀有）/ 1=铺满云纹（传说）
uniform float cloud_alpha : hint_range(0.0, 0.6) = 0.17; // 云纹强度（tone-on-tone·克制）
uniform float flow_freq = 2.2;                         // 云气线条数
uniform float warp_amt : hint_range(0.0, 0.4) = 0.12;  // 流动扭曲（swirl）
uniform float drift_speed = 0.12;                      // 漂移速度（TIME）
group_uniforms shape;
uniform float corner_radius : hint_range(0.0, 0.4) = 0.18; // 圆角（与外框一致）
uniform float pixel_grid : hint_range(8.0, 64.0) = 24.0;   // 圆角像素台阶（=格 px/6·与框对齐）
uniform float center_glow : hint_range(0.0, 1.0) = 0.0;    // 内外渐变强度（0=纯 fill_color / 1=中心全到 inner_color·凸显道具）
uniform float glow_radius : hint_range(0.1, 0.9) = 0.55;   // (保留·当前内外渐变未用)
uniform vec4 inner_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // 中心亮色（=稀有度亮调·参传说 gold_bottom 中心亮/四角深）
uniform float vertical_gradient : hint_range(0.0, 1.0) = 0.0; // 1=上暗(fill_color)→下亮(inner_color)；默认保留径向模式
uniform float material_lighting : hint_range(0.0, 1.0) = 0.0; // 1=偏上局部柔光+暗角+弱底部反光，代替整面轴向渐变

// 与 round_mask / pixel_frame 同一套像素台阶圆角逻辑（多层一起切·不露方角）。
float corner_round_alpha(vec2 uv, float rr, float pg) {
	if (rr <= 0.0) return 1.0;
	vec2 q = (floor(uv * pg) + 0.5) / pg;
	vec2 cc = min(q, vec2(1.0) - q);
	vec2 corner = vec2(rr) - cc;
	if (corner.x > 0.0 && corner.y > 0.0 && length(corner) > rr) return 0.0;
	return 1.0;
}

// 一朵涡卷云头：以 sc 为心的螺旋臂，仅近心可见（rad 衰减）。
float spiral(vec2 uv, vec2 sc, float t) {
	vec2 d = uv - sc;
	float r = length(d);
	float a = atan(d.y, d.x);
	float arm = sin(a + r * 34.0 - t * 0.5);          // 螺旋臂等值线
	return smoothstep(0.74, 0.96, abs(arm)) * smoothstep(0.30, 0.04, r);
}

void fragment() {
	float t = TIME * drift_speed;
	// 轻微 swirl 扭曲 → 云气有流动感
	vec2 q = UV;
	q.x += warp_amt * sin(UV.y * 6.2831853 + t);
	q.y += warp_amt * sin(UV.x * 6.2831853 * 0.8 - t * 0.7);
	// 流动云气线（两层对角等值线·一密一疏）
	float f1 = sin((q.x - q.y) * 6.2831853 * flow_freq);
	float lines = smoothstep(0.80, 0.97, abs(f1));
	float f2 = sin((q.x * 0.6 + q.y) * 6.2831853 * (flow_freq * 0.7) + 1.3);
	lines = max(lines, smoothstep(0.86, 0.99, abs(f2)) * 0.7);
	// 对角两朵涡卷云头
	lines = max(lines, spiral(UV, vec2(0.80, 0.20), t));
	lines = max(lines, spiral(UV, vec2(0.20, 0.80), t));
	lines *= step(0.5, cloud_on);                       // 无云纹时门控为 0（branchless）
	float cl = clamp(lines, 0.0, 1.0) * cloud_alpha;
	// 两模式无分支切换：实底(fill_opaque=1·图鉴)=底色+云纹混入·不透明；叠加(=0·战斗)=仅金云·低 alpha 覆在芯片上
	vec3 fill_col = mix(fill_color.rgb, cloud_color.rgb, cl);
	// 非传说底色：中心 inner_color(亮) → 四角 fill_color(深) 径向渐变。
	//   参传说 gold_bottom 实测内外区分（中心 V≈0.98 略浅 / 四角 V≈0.89 更深更饱和）→ 普通/稀有同款"亮而有内外层次"。
	float rr = clamp(distance(UV, vec2(0.5)) / 0.71, 0.0, 1.0);     // 0=中心 → 1=四角
	float rad = (1.0 - smoothstep(0.0, 1.0, rr)) * center_glow;     // 1中心 → 0角（center_glow=渐变强度）
	vec3 radial_proc = mix(fill_col, inner_color.rgb, rad);
	float vertical_t = smoothstep(0.06, 0.94, UV.y);
	vec3 vertical_proc = mix(fill_col, inner_color.rgb, vertical_t);
	vec3 legacy_proc = mix(radial_proc, vertical_proc, vertical_gradient);
	// 道具图鉴暗色材质：光源集中在图标后上方，而不是从上到下均匀换色。
	vec2 light_delta = (UV - vec2(0.46, 0.40)) / vec2(0.76, 0.64);
	float local_light = 1.0 - smoothstep(0.18, 0.88, length(light_delta));
	// 量化成有限明度层，让小尺寸像素格更像材质分色，不像无限平滑的演示文稿渐变。
	local_light = floor(local_light * 8.0 + 0.5) / 8.0;
	float edge_shade = smoothstep(0.48, 0.76, distance(UV, vec2(0.5)));
	float bottom_bounce = smoothstep(0.72, 0.98, UV.y)
		* (1.0 - smoothstep(0.16, 0.52, abs(UV.x - 0.5)));
	vec3 lit_proc = mix(fill_col, inner_color.rgb, local_light * 0.62);
	lit_proc *= 1.0 - edge_shade * 0.14;
	lit_proc = mix(lit_proc, inner_color.rgb, bottom_bounce * 0.09);
	vec3 proc = mix(legacy_proc, lit_proc, material_lighting);
	// 传说: 美术背景图(压暗)替代程序渐变；最后统一过 corner_round_alpha 裁圆角。
	vec3 tex_color = texture(bg_tex, UV).rgb * tex_tint.rgb;
	float top_weight = 1.0 - smoothstep(0.04, 0.68, UV.y);
	tex_color *= 1.0 - top_weight * tex_top_darkening;
	vec3 solid = mix(proc, tex_color, use_tex);
	COLOR.rgb = mix(cloud_color.rgb, solid, fill_opaque);
	COLOR.a = mix(cl, 1.0, fill_opaque);
	COLOR.a *= corner_round_alpha(UV, corner_radius, pixel_grid);
}
