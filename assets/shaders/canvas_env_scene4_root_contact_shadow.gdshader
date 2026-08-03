shader_type canvas_item;
render_mode unshaded, blend_mix;

// Compact root-like contact shadow for Scene4. It anchors each fighter to the
// tree platform without borrowing Scene1's moon-directed long shadow.
uniform vec4 shadow_color : source_color = vec4(0.018, 0.070, 0.043, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.62;
uniform vec2 grid_cells = vec2(44.0, 12.0);
uniform float alpha_levels : hint_range(2.0, 8.0, 1.0) = 4.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float ellipse_mask(vec2 uv, vec2 center, vec2 radius) {
	vec2 delta = (uv - center) / max(radius, vec2(0.001));
	return 1.0 - smoothstep(0.52, 1.0, length(delta));
}


void fragment() {
	vec2 cells = max(grid_cells, vec2(1.0));
	vec2 uv = (floor(UV * cells) + vec2(0.5)) / cells;
	float core = ellipse_mask(uv, vec2(0.50, 0.56), vec2(0.30, 0.24));
	float left_root = ellipse_mask(uv, vec2(0.31, 0.61), vec2(0.25, 0.12));
	float right_root = ellipse_mask(uv, vec2(0.69, 0.61), vec2(0.25, 0.12));
	float roots = max(core, max(left_root, right_root) * 0.72);
	float alpha = floor(
			clamp(roots * shadow_strength, 0.0, 1.0)
			* alpha_levels + 0.5
	) / alpha_levels;
	if (alpha <= 0.001) {
		discard;
	}
	COLOR = vec4(shadow_color.rgb, alpha * shadow_color.a) * node_modulate;
}
