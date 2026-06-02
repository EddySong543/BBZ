shader_type canvas_item;

// =============================================================
// canvas_fx_moonlight.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 主屋脊"月光缓缓波动"
//   屋脊贴图自带烘焙光照(死光)，无法移动光源。本着色器叠在贴图之上，
//   对"已经被月光照亮的亮部"施加极慢、偏向月亮来向的强度起伏 + 整体呼吸，
//   暗部几乎不动 → 读作"月光在屋脊上流动"，而非整图闪烁。让静止画面有了呼吸感。
//
//   ⚠ 设计修订(2026-06-02)：波动改为【只加光、永不压暗】——
//     · pulse 重映射到 [0,1]，gain 恒 ≥ 0，屋脊只会从原亮度往上"涨"再"落回"原亮度，绝不更暗。
//     · 冷月色 tint 由"乘法压暗"改为"叠加式冷辉光"(additive)，只加不减。
//     修订前的对称波动 + 乘法 tint 会在波谷/染色处净变暗，是画面发暗的元凶。
//
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 每像素 ~3 次廉价 sin + 1 纹理采样、屏幕下半带 → 低。
//   (无循环 / 无循环内采样 / 用 sin 叠加代替 noise 纹理，符合性能规范)
// =============================================================

group_uniforms wave;
uniform vec2 moon_dir = vec2(0.6, -0.8);          // 月光来向(指向月亮，屋脊本地 UV：右=+x 上=-y)，决定波动掠过方向
uniform float wave_speed : hint_range(0.0, 1.0) = 0.12;     // 波动速度(极慢)
uniform float wave_scale : hint_range(0.5, 6.0) = 2.0;      // 空间密度(小=大块缓动光带)
uniform float wave_strength : hint_range(0.0, 0.4) = 0.10;  // 亮部"上涨"峰值幅度(只加光)
uniform float breath_strength : hint_range(0.0, 0.2) = 0.04;// 整体呼吸幅度(只加光)

group_uniforms mask;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.35; // 只对亮于此的像素施加(保护暗部不动)
uniform float highlight_softness : hint_range(0.05, 0.8) = 0.40;

group_uniforms tint;
uniform vec4 moon_tint : source_color = vec4(0.78, 0.88, 1.0, 1.0); // 波峰处叠加的冷月辉光颜色
uniform float tint_strength : hint_range(0.0, 2.0) = 0.6;           // 冷辉光叠加强度(只加不减)

void fragment() {
	vec4 modc = COLOR;                          // 顶点色×节点 modulate(保持默认行为)
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * modc;

	float t = TIME * wave_speed;
	vec2 dir = normalize(moon_dir);

	// 沿月光来向的投影坐标 → 大尺度光带从月亮方向缓缓推进
	float along = dot(dir, UV);
	float w1 = sin(along * wave_scale * 6.28318 - t);
	// 交叉方向的慢扰动，打破纯条纹规律，更有机
	float w2 = sin((UV.x + UV.y) * wave_scale * 2.7 + t * 0.7) * 0.5;
	float field = (w1 + w2) / 1.5;              // ~[-1,1]
	float pulse = field * 0.5 + 0.5;            // → [0,1]：月光"涨落"，最低只回到原亮度，绝不压暗

	// 只增强已被照亮的亮部(月光落点)，暗部权重→0
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float hl = smoothstep(highlight_threshold, highlight_threshold + highlight_softness, lum);

	float breath = (sin(t * 1.3) * 0.5 + 0.5) * breath_strength;  // [0,breath]：只加光
	float gain = (pulse * wave_strength + breath) * hl;           // 恒 ≥ 0 → 永不变暗

	vec3 col = base.rgb * (1.0 + gain);                 // 中性提亮(保留原色相)
	col += moon_tint.rgb * gain * tint_strength * 0.25; // 叠加式冷月辉光(只加不减)

	COLOR = vec4(col, base.a);
}
