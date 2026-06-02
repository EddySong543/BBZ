shader_type canvas_item;

// =============================================================
// canvas_fx_motion_blur.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 快速前景落叶的方向性运动模糊
//   沿 blur_dir（叶子飞行方向）做多抽样平均 → 高速移动的叶子呈"拖影/虚化"，
//   而非清晰贴片，配合快速飞过全屏的落叶。挂在 FallingLeaves(GPUParticles2D) 的 material 上，
//   所有叶子共用同一方向（它们都同向飞）。末尾乘 COLOR 保留粒子色/alpha。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 9 次纹理采样、仅叶子小 quad → 极低。
// =============================================================

uniform vec2 blur_dir = vec2(0.87, 0.49);                 // 模糊方向(叶子飞行方向，右下；与 LeafMat.direction 一致)
uniform float blur_amount : hint_range(0.0, 0.2) = 0.06;  // 模糊长度(UV)；越大拖影越长

const int SAMPLES = 9;

void fragment() {
	vec2 stepv = normalize(blur_dir) * blur_amount;
	vec4 sum = vec4(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float t = float(i) / float(SAMPLES - 1) - 0.5;   // -0.5 .. 0.5，居中
		sum += texture(TEXTURE, UV + stepv * t);
	}
	COLOR = (sum / float(SAMPLES)) * COLOR;
}
