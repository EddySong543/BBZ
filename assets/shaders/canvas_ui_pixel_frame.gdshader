shader_type canvas_item;

// =============================================================
// canvas_ui_pixel_frame.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 英雄头像框(竹节像素框 2b-Y) —— 仅画多层像素边框 + 噪点质感。
//   像素网格多层边框(外暗轮廓 + 中阵营色 + 内深阵营) + 像素噪点。中心透明 → 让满幅头像/底色透出。
//   ★ 四角菱形角饰改由 hero_frame.gd 的 _draw 用矢量 draw_colored_polygon 叠加(更平滑醒目)，
//     shader 不再画角饰。阵营色/状态由 hero_frame.gd 设 uniform。近方形框(aspect≈1)。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 小 quad、少量 hash → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item）。
// =============================================================

group_uniforms palette;
uniform vec4 edge_outer : source_color = vec4(0.04, 0.04, 0.06, 1.0);  // 外暗轮廓
uniform vec4 edge_mid : source_color = vec4(0.3, 0.5, 0.85, 1.0);      // 中阵营色(主)
uniform vec4 edge_inner : source_color = vec4(0.15, 0.25, 0.45, 1.0);  // 内深阵营
group_uniforms;

group_uniforms shape;
uniform float pixel_grid : hint_range(12.0, 200.0) = 24.0; // 像素格数(框宽高，越大格越细)
uniform float border_px : hint_range(1.0, 6.0) = 2.0;      // 中层边框宽(像素格)
uniform float noise_amt : hint_range(0.0, 0.2) = 0.06;     // 像素噪点质感
uniform float corner_radius : hint_range(0.0, 0.4) = 0.0;  // 圆角半径(高度UV比例,0=直角)；像素台阶圆角
uniform float aspect : hint_range(0.1, 10.0) = 1.0;        // 宽/高比：非方形节点圆角等圆修正(1=方形,旧调用不受影响)
group_uniforms;

// 大框增质三件套（2026-06-11 反"毛坯房"·默认全关=旧效果逐位一致，battle 小头像框不受影响）
group_uniforms enrich;
uniform float accent_strength : hint_range(0.0, 1.0) = 0.0;  // O1 内缘镀线强度(0=关)
uniform vec4 accent_color : source_color = vec4(0.30, 0.55, 0.85, 1.0);  // 月光青(hover 时调金)
uniform float light_amount : hint_range(0.0, 0.5) = 0.0;     // O2 方向光：上/左提亮、下/右压暗(0=关)
uniform float node_count : hint_range(0.0, 3.0) = 0.0;       // O3 每边竹节数(0=关)
group_uniforms;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	float pg = pixel_grid;
	vec2 cell = floor(UV * pg);

	// 到最近边的整格距(方形 pg×pg)
	float dl = cell.x;
	float dr = pg - 1.0 - cell.x;
	float dt = cell.y;
	float db = pg - 1.0 - cell.y;
	float edge_dist = min(min(dl, dr), min(dt, db));

	// 圆角(像素台阶)：角落 rr 区内边距改用圆弧径向距离 → 边框三层沿圆弧转过去
	// （只切 mask 会露出"被啃掉的黑角"，边框线必须包弧）。圆弧外 → 整体切掉。
	// 非方形修正：x 距离乘 aspect 换算到以高度为基准的等比空间，防竖牌椭圆角。
	float corner_cut = 1.0;
	if (corner_radius > 0.0) {
		vec2 q = (cell + vec2(0.5)) / pg;     // 像素格中心
		vec2 cc = vec2(min(q.x, 1.0 - q.x) * aspect, min(q.y, 1.0 - q.y));
		vec2 cv = vec2(corner_radius) - cc;   // 进入角落 rr 区的深度
		if (cv.x > 0.0 && cv.y > 0.0) {
			float rd = (corner_radius - length(cv)) * pg;  // 圆弧内侧径向边距(折算成格)
			corner_cut = step(0.0, rd);
			edge_dist = rd;
		}
	}

	vec4 col = vec4(0.0);  // 中心透明 → 头像/底色透出

	// 多层边框：外 1 格暗轮廓 → 中 border_px 格阵营色 → 内 1 格深阵营(可镀 accent 线)
	if (edge_dist < 1.0) {
		col = edge_outer;
	} else if (edge_dist < border_px) {
		col = edge_mid;
	} else if (edge_dist < border_px + 1.0) {
		// O1 内缘镀线：深内线 → 月光青/亮金细线（毛坯房→镶边）
		col = mix(edge_inner, accent_color, accent_strength);
	}

	// O2 方向光：上缘最亮、左缘次亮、下/右压暗 → 边框有体积不再平涂
	if (light_amount > 0.0 && col.a > 0.0 && edge_dist < border_px + 1.0) {
		float lf = 0.0;
		if (dt <= min(min(dl, dr), db)) {
			lf = 1.0;
		} else if (db <= min(dl, dr)) {
			lf = -1.0;
		} else if (dl < dr) {
			lf = 0.5;
		} else {
			lf = -0.5;
		}
		col.rgb *= 1.0 + lf * light_amount;
	}

	// O3 竹节：每边 node_count 个节块（节侧深刻痕 + 节心亮线），长边不再光秃
	if (node_count > 0.5 && col.a > 0.0 && edge_dist < border_px + 1.0) {
		bool on_h = min(dt, db) <= min(dl, dr);
		float t = (on_h ? cell.x : cell.y) / max(pg - 1.0, 1.0);
		float n = max(node_count, 1.0);
		float tn = (floor(t * n) + 0.5) / n;       // 最近节心（每边 n 等分段中点）
		float dc = abs(t - tn) * (pg - 1.0);
		if (dc < 0.7) {
			col.rgb *= 1.35;                        // 节心亮线
		} else if (dc < 2.0) {
			col.rgb = edge_outer.rgb;               // 节侧深刻痕
		}
	}

	// 像素噪点质感(透明处 col=0 不受影响)
	col.rgb *= 1.0 + (hash(cell) - 0.5) * noise_amt;

	// 圆角：圆弧外整体切掉（边框分层已在上方沿弧重算）
	col.a *= corner_cut;

	COLOR = col * COLOR;  // 乘 incoming COLOR(携带 modulate) → 跟随父节点变暗(需节点 color=白)
}
