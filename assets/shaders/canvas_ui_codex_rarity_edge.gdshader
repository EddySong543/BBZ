shader_type canvas_item;

// 直接复用纸签纹理的 Alpha、明暗与纤维色，让稀有度色成为纸边染色而非覆盖贴图。
uniform vec4 rarity_color : source_color = vec4(0.35, 0.62, 0.75, 1.0);
uniform float edge_end_uv : hint_range(0.0, 1.0) = 0.34;
uniform float blend_width_uv : hint_range(0.001, 0.2) = 0.04;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.88;

void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	float edge_mask = 1.0 - smoothstep(
			edge_end_uv - blend_width_uv,
			edge_end_uv,
			UV.x);
	float paper_luma = dot(paper.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dyed_paper = rarity_color.rgb * mix(0.62, 1.12, paper_luma);
	vec3 integrated_color = mix(paper.rgb, dyed_paper, tint_strength);
	COLOR = vec4(integrated_color, paper.a * edge_mask * rarity_color.a);
}
