shader_type canvas_item;

// 头像「只收下半」菱形遮罩（2026-07-18·ref10 左侧头像语言）：
// 菱形横对角线**以下**且出界 → 剪掉（下巴被菱形收住）；对角线**以上**完全不剪
// （头发/头顶自由溢出框外 = ref10 的关键观感）。
// 菱形参数用**本节点局部像素坐标**传入 → 头像节点可以比框大/可以上移，遮罩仍与框严丝合缝。

uniform vec2 node_size_px = vec2(72.0, 72.0);    // 本节点像素尺寸
uniform vec2 dia_center_px = vec2(36.0, 36.0);   // 菱形中心（本节点局部像素坐标）
uniform vec2 dia_half_px = vec2(36.0, 36.0);     // 菱形半宽/半高
uniform float inset_px = 3.0;                    // 内缩：留出描边环不被头像盖住
uniform bool flip_h = false;                     // TextureRect.flip_h 后把遮罩坐标反翻，保持敌我严格镜像
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.0) = 1.0;
// 横对角线**以上**的收口：**负数 = 完全不收**（默认·ref10 原意：上半头像盖过上半框）。
// ≥0 则把菱形顶点往上拉长这么多像素再收口（0=上下一样收死）。
// ⚠只加在 y 半轴、x 半轴不动 → 中线处上下宽度相等，不会在腰上豁出一个台阶。
uniform float top_slack_px = -1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 local_px = UV * node_size_px;
	if (flip_h) {
		local_px.x = node_size_px.x - local_px.x;
	}
	vec2 p = local_px - dia_center_px;
	vec2 h = max(dia_half_px - inset_px, vec2(1.0));
	bool clip = true;
	if (p.y <= 0.0) {
		if (top_slack_px < 0.0) {
			clip = false;                        // 上半不收
		} else {
			h.y += top_slack_px;
		}
	}
	if (clip && abs(p.x) / h.x + abs(p.y) / h.y > 1.0) {
		c.a = 0.0;
	}
	// ⚠rgb 必须用**纯纹理**、不乘 COLOR：TextureRect 的 incoming COLOR 已含纹理，
	// 再乘一次 = 纹理²，整张头像被压黑（Eddy 2026-07-18 一眼看出·canvas_ui_portrait_pixelate
	// 第 42 行早就写明这条，我没照做，踩了同一个坑）。仅 alpha 跟 modulate.a → 淡入淡出照常。
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(c.rgb, vec3(gray), desaturation) * brightness;
	COLOR = vec4(graded, c.a * COLOR.a);
}
