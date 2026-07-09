shader_type canvas_item;

// =============================================================
// canvas_env_fog_band.gdshader
// 作者: Claude (Game Studios) ｜ 用途: scene1 近景雾带（任务 D 近景框·2026-07-09 Eddy 批）
//   一条极低透明度的近景流动雾，压在底部近景屋脊之上 → 拉开近景与主舞台的空气纵深。
//   ⚠ 反"脏"纪律：alpha 封顶 ≤0.15（默认 0.10）·色相=天空同族冷蓝灰·极慢漂移·
//     上下边缘 sin 淡出（无硬边）·横向双频起伏打破均匀（无噪点）。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 每像素 3 次 sin → 极低。
// =============================================================

uniform vec4 fog_color : source_color = vec4(0.55, 0.65, 0.80, 1.0);  // 雾色（冷蓝灰·天空同族）
uniform float alpha_max : hint_range(0.0, 0.15) = 0.10;               // 最浓处透明度（反脏封顶）
uniform float drift_speed : hint_range(0.0, 0.05) = 0.010;            // 漂移速度（极慢）
uniform float scale_x : hint_range(0.5, 6.0) = 2.0;                   // 横向起伏密度


void fragment() {
	float t = TIME * drift_speed * 6.2832;
	float vy = sin(UV.y * 3.14159);   // 纵向权重：中间最浓·上下淡出到 0
	// 横向双频起伏：雾有疏密、缓慢流动，不是均匀一条
	float w = 0.55 + 0.45 * sin(UV.x * 6.2832 * scale_x + t)
			* sin(UV.x * 6.2832 * scale_x * 0.53 - t * 0.7);
	COLOR = vec4(fog_color.rgb, alpha_max * vy * clamp(w, 0.0, 1.0));
}
