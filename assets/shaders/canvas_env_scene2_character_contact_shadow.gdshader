shader_type canvas_item;
render_mode unshaded;

// A compact pixel-stepped contact shadow for Scene2's bridge deck. The source
// gradient supplies the ellipse; this pass snaps it into stable alpha bands.
uniform vec4 shadow_color : source_color = vec4(0.07, 0.16, 0.13, 0.62);
uniform vec2 grid_cells = vec2(40.0, 10.0);
uniform float alpha_levels : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float core_strength : hint_range(0.0, 0.5) = 0.16;
uniform float contact_center_x : hint_range(0.35, 0.7, 0.01) = 0.56;
uniform float tail_offset_x : hint_range(-0.3, 0.3, 0.01) = -0.14;
uniform float tail_strength : hint_range(0.0, 0.5, 0.01) = 0.18;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


void fragment() {
	vec2 cells = max(grid_cells, vec2(1.0));
	vec2 snapped_uv = (floor(UV * cells) + vec2(0.5)) / cells;
	float source_alpha = texture(TEXTURE, snapped_uv).a;
	float contact_core = 1.0 - smoothstep(
			0.0,
			0.34,
			length(vec2(
					(snapped_uv.x - contact_center_x) * 0.72,
					(snapped_uv.y - 0.5) * 2.8)));
	float directional_tail = 1.0 - smoothstep(
			0.0,
			0.42,
			length(vec2(
					(snapped_uv.x - contact_center_x - tail_offset_x) * 0.88,
					(snapped_uv.y - 0.56) * 3.2)));
	float alpha = clamp(
			source_alpha
					+ contact_core * core_strength
					+ directional_tail * tail_strength,
			0.0,
			1.0);
	alpha = floor(alpha * alpha_levels + 0.5) / alpha_levels;
	COLOR = vec4(shadow_color.rgb, alpha * shadow_color.a) * node_modulate;
}
