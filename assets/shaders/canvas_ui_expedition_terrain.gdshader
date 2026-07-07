shader_type canvas_item;

// =============================================================
// canvas_ui_expedition_terrain.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 远征屏 12×12 地图「地形+迷雾」程序母题（2026-07-07·精细化 A/B/C 批）。
//   数据纹理驱动（map_data 12×12 RGBAF: R=地形类 0地板/1墙 · G=已探明 0/1 · B=探明时刻秒）——
//   单节点全程序渲染，取代逐格 draw_rect：
//     地板 = 三味聚落（泥地/草地/碎石·2×2 格聚落哈希）+ 粗格块三档明度 + 草地稀疏亮斑缓慢呼吸；
//     墙体 = 顶缘受光条 + 底缘阴影条（沿用旧 draw_wall 斜面语言）+ 块哈希碎岩；
//     迷雾 = 暖黑纱两层慢波缓流（⛔冷靛·全暖色系=Eddy 2026-07-06 定）+ 探明邻边微光（迷雾在边缘"变薄"）；
//     揭示 = 逐粗格块 dissolve 翻显（块哈希阈值）+ 瞬时过亮回落。
//   像素语言与全项目统一（ui-design-system §5 像素粗格法）：block_px 整块纯色、无平滑无抖动、
//   空间量化一律用块心坐标（bc）。格间沟槽 alpha=0 透出面板底色（对齐旧逐格 2px 间隙）。
//   ⚠ 片元无循环纹理采样：邻格探明检查 = 4 次采样手工展开（越界用 in-bounds mask 归零）。
//   正式美术地形贴图（MJ/pixellab）到位后：本节点换 TextureRect 图集渲染，数据纹理接口可续用。
// 时间驱动: expedition_screen.gd 每帧累加 anim_time uniform（同一时钟也用于 reveal_time 戳）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 低（5 次 12×12 数据纹理采样 + 数条 sin/hash·672×672 区域）。
// 渲染管线: Godot 4.x Forward+（2D canvas_item）。
// =============================================================

uniform sampler2D map_data : filter_nearest, repeat_disable;  // 12×12 RGBAF（R=tile G=revealed B=reveal_time）
uniform float grid_n = 12.0;        // 地图边格数
uniform float cell_px = 56.0;       // 单格像素边长（含沟槽）
uniform float gutter_px = 2.0;      // 格间沟槽宽（alpha=0 透面板底色）
uniform float block_px = 4.0;       // 粗格法块边长（整块纯色）
uniform float anim_time = 0.0;      // 由 expedition_screen 每帧累加
uniform float seed_f = 0.0;         // 本局种子（换局换地貌聚落）

group_uniforms terrain_palette;
uniform vec3 floor_dirt : source_color = vec3(0.208, 0.163, 0.104);    // 泥地基色（COL_FLOOR #2e2417 提亮一档·迷雾有纹理后需拉开对比）
uniform vec3 floor_grass : source_color = vec3(0.176, 0.204, 0.098);   // 草地橄榄暖绿（压暗档·⛔艳绿）
uniform vec3 floor_stone : source_color = vec3(0.235, 0.212, 0.167);   // 碎石暖灰（近暖骨低明度档）
uniform vec3 wall_base : source_color = vec3(0.082, 0.063, 0.039);     // 墙基色 = COL_WALL #15100a
uniform float grass_ratio : hint_range(0.0, 1.0) = 0.30;               // 草地聚落占比
uniform float stone_ratio : hint_range(0.0, 1.0) = 0.20;               // 碎石聚落占比
group_uniforms;

group_uniforms fog_and_reveal;
uniform vec3 fog_base : source_color = vec3(0.051, 0.039, 0.024);      // 迷雾基色 = COL_FOG #0d0a06
uniform vec3 fog_edge_tint : source_color = vec3(0.165, 0.125, 0.078); // 探明邻边微光（暖调）
uniform float fog_flow_amp : hint_range(0.0, 1.2) = 0.40;              // 迷雾明度缓流幅度（过大与地板混读）
uniform float fog_flow_speed : hint_range(0.0, 2.0) = 0.30;            // 迷雾缓流速率
uniform float edge_glow_amt : hint_range(0.0, 1.0) = 0.55;             // 探明邻边微光强度
uniform float reveal_dur : hint_range(0.1, 1.5) = 0.35;                // 揭示翻显时长（秒）
uniform float reveal_flash : hint_range(0.0, 1.0) = 0.35;              // 揭示瞬时过亮幅度
group_uniforms;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * grid_n * cell_px;                       // 区域内像素坐标（0..grid_n*cell_px）
	vec2 tile = floor(px / cell_px);                       // 所在地图格
	vec2 in_cell = px - tile * cell_px;                    // 格内像素（沟槽判定用原始坐标·保 2px 锐利）
	vec2 block = floor(px / block_px);                     // 粗格块坐标（全区连续）
	vec2 bc = (floor(in_cell / block_px) + 0.5) * block_px; // 格内块心坐标（一切空间渐变按块量化）
	float bh = hash21(block + vec2(seed_f));               // 块哈希（明度档/翻显阈值共用）

	vec4 d = texture(map_data, (tile + 0.5) / grid_n);
	float is_wall = step(0.5, d.r);
	float revealed = step(0.5, d.g);

	// —— 地板三味聚落：2×2 格聚落哈希 → 泥地(默认)/草地/碎石 ——
	float fh = hash21(floor(tile / 2.0) + vec2(seed_f * 1.7 + 31.0));
	float grass_lo = 1.0 - grass_ratio - stone_ratio;      // [grass_lo, 1-stone_ratio) = 草
	float is_grass = step(grass_lo, fh) * (1.0 - step(1.0 - stone_ratio, fh));
	float is_stone = step(1.0 - stone_ratio, fh);
	vec3 fl = mix(floor_dirt, floor_grass, is_grass);
	fl = mix(fl, floor_stone, is_stone);
	// 块三档明度（对齐旧 draw_floor 的 3-shade 语言·档位更细）
	float sh = mix(0.90, 1.0, step(0.33, bh));
	sh = mix(sh, 1.07, step(0.66, bh));
	fl *= sh;
	// 草地稀疏亮斑呼吸（微动·不抢主体）
	float fleck = step(0.86, hash21(block + vec2(7.3, 2.1)));
	float sway = 0.5 + 0.5 * sin(anim_time * 1.3 + bh * 6.28);
	fl += vec3(0.055, 0.075, 0.028) * fleck * sway * is_grass;
	// 碎石偶发亮砾
	fl += vec3(0.050, 0.045, 0.034) * step(0.84, hash21(block + vec2(3.7, 9.2))) * is_stone;

	// —— 墙体：块哈希碎岩 + 顶缘受光 / 底缘阴影（斜面语言沿用旧 draw_wall）——
	vec3 wl = wall_base * sh;
	float strip = cell_px / 8.0;
	wl = mix(wl, wl + (vec3(1.0) - wl) * 0.22, step(bc.y, strip));                       // 顶缘受光条
	wl = mix(wl, wl * 0.65, step(cell_px - gutter_px - strip, bc.y));                    // 底缘阴影条

	vec3 terrain = mix(fl, wl, is_wall);

	// —— 迷雾：暖黑纱两层慢波缓流（按块量化 3 档·幅度克制）——
	float flow = sin(block.x * 0.55 + anim_time * fog_flow_speed)
			* sin(block.y * 0.47 - anim_time * fog_flow_speed * 0.8)
			+ 0.6 * sin((block.x + block.y) * 0.31 + anim_time * fog_flow_speed * 0.7);
	float fq = floor((flow * 0.31 + 0.5) * 3.0) / 3.0;     // flow∈[-1.6,1.6] → 0..1 → 3 档
	vec3 fog_col = fog_base * (1.0 - fog_flow_amp * 0.5 + fq * fog_flow_amp);

	// —— 探明邻边微光：4 邻格采样（手工展开·越界 mask 归零）→ 迷雾靠近已探明区"变薄" ——
	float n_r = step(0.5, texture(map_data, (tile + vec2(1.5, 0.5)) / grid_n).g) * step(tile.x, grid_n - 1.5);
	float n_l = step(0.5, texture(map_data, (tile + vec2(-0.5, 0.5)) / grid_n).g) * step(0.5, tile.x);
	float n_d = step(0.5, texture(map_data, (tile + vec2(0.5, 1.5)) / grid_n).g) * step(tile.y, grid_n - 1.5);
	float n_u = step(0.5, texture(map_data, (tile + vec2(0.5, -0.5)) / grid_n).g) * step(0.5, tile.y);
	float glow = n_r * smoothstep(cell_px * 0.35, cell_px, bc.x)
			+ n_l * smoothstep(cell_px * 0.65, 0.0, bc.x)
			+ n_d * smoothstep(cell_px * 0.35, cell_px, bc.y)
			+ n_u * smoothstep(cell_px * 0.65, 0.0, bc.y);
	fog_col = mix(fog_col, fog_edge_tint, clamp(glow, 0.0, 1.0) * edge_glow_amt);

	// —— 揭示翻显：逐块 dissolve（块哈希阈值）+ 瞬时过亮回落 ——
	float prog = clamp((anim_time - d.b) / reveal_dur, 0.0, 1.0);
	float show = step(hash21(block + vec2(seed_f + 51.0)), prog) * revealed;
	vec3 col = mix(fog_col, terrain * (1.0 + reveal_flash * (1.0 - prog)), show);

	// 沟槽（右/下 gutter_px）alpha=0 透面板底色 = 保住网格阅读
	float gut = step(cell_px - gutter_px, in_cell.x) + step(cell_px - gutter_px, in_cell.y);
	COLOR = vec4(col, 1.0 - clamp(gut, 0.0, 1.0));
}
