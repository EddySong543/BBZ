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
group_uniforms cloud;
uniform float cloud_on = 0.0;                          // 0=无云纹（普通/稀有）/ 1=铺满云纹（传说）
uniform float cloud_alpha : hint_range(0.0, 0.6) = 0.17; // 云纹强度（tone-on-tone·克制）
uniform float flow_freq = 2.2;                         // 云气线条数
uniform float warp_amt : hint_range(0.0, 0.4) = 0.12;  // 流动扭曲（swirl）
uniform float drift_speed = 0.12;                      // 漂移速度（TIME）
group_uniforms shape;
uniform float corner_radius : hint_range(0.0, 0.4) = 0.18; // 圆角（与外框一致）
uniform float pixel_grid : hint_range(8.0, 64.0) = 24.0;   // 圆角像素台阶（=格 px/6·与框对齐）

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
	COLOR.rgb = mix(cloud_color.rgb, fill_col, fill_opaque);
	COLOR.a = mix(cl, 1.0, fill_opaque);
	COLOR.a *= corner_round_alpha(UV, corner_radius, pixel_grid);
}
