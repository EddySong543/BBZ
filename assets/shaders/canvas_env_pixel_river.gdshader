shader_type canvas_item;

// =============================================================
// canvas_env_pixel_river.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 近景像素河流带（scene2 招牌件·Kingdom Two Crowns
//   式水面技法的自研实现）——屏幕空间倒影（水线=节点顶边·纵向镜采上方已绘场景）+
//   逐深度横向波纹扰动 + 倒影色阶化压入像素画 + 错相闪点（波光粼粼）+ 岸线亮边。
//   全程整像素格量化（档中点）·时间走档位步进（像素帧率）→ 零爬缝零噪闪。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 低（每像素 1 次屏幕采样 + 哈希）。
// 渲染管线: Godot 4.7 Forward+（2D canvas_item·hint_screen_texture 自动背拷）。
// ⚠ 树序=物理序：本节点之前绘制的层（天空/山/岸）才会入倒影；角色在 stage 之后绘制=不反射（省·静）。
// =============================================================

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

group_uniforms layout;
uniform vec2 size_px = vec2(2016.0, 180.0);     // 节点实际尺寸（量化基准·须与 tscn 一致）
uniform vec2 screen_px = vec2(1920.0, 1080.0);  // 画布尺寸
uniform float px_size = 3.0;                    // 水面像素块尺寸
group_uniforms;

group_uniforms reflection;
uniform float stretch = 1.15;                   // 倒影纵向拉伸（>1 映入更高处的景）
uniform float wobble_px = 3.0;                  // 倒影横向扰动幅度（px·随深度增强）
uniform float wobble_freq = 46.0;               // 扰动竖向频率
uniform float flow_speed = 0.5;                 // 扰动相位流速（水在横流）
uniform float refl_strength : hint_range(0.0, 1.0) = 0.55;  // 倒影混入强度（近水线最强）
uniform float refl_levels = 5.0;                // 倒影色阶量化（压入像素画）
group_uniforms;

group_uniforms water;
uniform vec4 deep_color : source_color = vec4(0.05, 0.11, 0.12, 1.0);    // 深水色（带底）
uniform vec4 shallow_tint : source_color = vec4(0.3, 0.48, 0.44, 1.0);   // 浅水色（近水线）
uniform float depth_curve = 1.3;                // 深度渐变曲线
uniform float row_shade : hint_range(0.0, 0.3) = 0.08;  // 静态横纹明暗（水面质感·无时间项）
group_uniforms;

group_uniforms sparkle;
uniform float anim_fps = 8.0;                   // 波光档位帧率（像素风步进）
uniform float sparkle_density : hint_range(0.0, 0.5) = 0.055;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform vec2 sparkle_cell = vec2(7.0, 3.0);     // 闪点格尺寸（px·横长=拉出粼光短横）
group_uniforms;

group_uniforms shore;
uniform vec4 foam_color : source_color = vec4(0.72, 0.85, 0.78, 1.0);   // 岸线亮边
uniform float foam_px = 2.0;                    // 岸线亮边高度（px）
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(511.0, 257.0));             // 大数取模（稳定性铁律）
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float t = floor(TIME * anim_fps) / anim_fps;                 // 档位时间
	// 整像素格量化（档中点采样）
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;
	// 波纹扰动：两组正弦叠加·幅度随深度增强·相位随档位时间横流
	float wob = sin(quv.y * wobble_freq + px.x * 0.045 + t * flow_speed * 6.2832)
			+ 0.5 * sin(quv.y * wobble_freq * 2.7 - t * flow_speed * 4.4);
	float wob_amt = wob * wobble_px * (0.35 + 0.65 * quv.y);
	// 屏幕空间镜面采样：水线=节点顶边（由本片元 UV↔SCREEN_UV 关系反推·随节点移动自洽）
	vec2 suv = SCREEN_UV + (quv - UV) * size_px / screen_px;     // 量化偏移映射到屏幕 UV
	float band_frac = size_px.y / screen_px.y;
	float waterline = suv.y - quv.y * band_frac;
	float d = suv.y - waterline;
	vec2 ruv = vec2(suv.x + wob_amt / screen_px.x, waterline - d * stretch);
	ruv.y = clamp(ruv.y, 0.001, max(waterline - 0.001, 0.001));
	vec3 refl = texture(screen_tex, ruv).rgb;
	refl = floor(refl * refl_levels) / refl_levels;              // 倒影色阶化
	// 水体基色：深度渐变 + 静态横纹（每格行随机微明暗·无时间项=零闪烁）
	float depth = pow(quv.y, depth_curve);
	vec3 water = mix(shallow_tint.rgb, deep_color.rgb, depth);
	water *= 1.0 - row_shade * 0.5 + row_shade * hash21(vec2(floor(px.y / px_size), 7.0));
	vec3 col = mix(water, refl * (1.0 - 0.3 * depth), refl_strength * (1.0 - 0.55 * depth));
	// 波光闪点：格错相慢档换批（~1s）+ 快档明暗呼吸·集中在中带
	vec2 cell = floor(px / sparkle_cell);
	float h0 = hash21(cell);
	float slot = floor(TIME * 0.9 + h0 * 9.0);
	float lit = step(1.0 - sparkle_density, hash21(cell + vec2(slot, 3.0)));
	float tw = 0.7 + 0.3 * step(0.5, fract(TIME * anim_fps * 0.5 + h0));
	float smask = smoothstep(0.02, 0.12, quv.y) * (1.0 - smoothstep(0.55, 0.95, quv.y));
	col = mix(col, sparkle_color.rgb, lit * tw * smask);
	// 岸线亮边（顶缘 foam_px 像素·水陆交界的一线光）
	float foam = 1.0 - step(foam_px / size_px.y, quv.y);
	col = mix(col, foam_color.rgb, foam * 0.8);
	COLOR = vec4(col, 1.0);
}
