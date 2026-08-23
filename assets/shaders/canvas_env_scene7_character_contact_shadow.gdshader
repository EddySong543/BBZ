shader_type canvas_item;
render_mode unshaded, blend_mix;

// Two short pixel contacts ground each fighter on the raised, damp road.
uniform vec4 shadow_color : source_color = vec4(0.035, 0.14, 0.13, 1.0);
uniform vec4 wet_edge_color : source_color = vec4(0.11, 0.31, 0.27, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.60;
uniform float wet_edge_strength : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform vec2 grid_cells = vec2(44.0, 10.0);
uniform float alpha_levels : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float left_foot_x : hint_range(0.2, 0.5, 0.01) = 0.40;
uniform float right_foot_x : hint_range(0.5, 0.8, 0.01) = 0.62;
uniform float foot_width : hint_range(0.08, 0.3, 0.01) = 0.17;
uniform float foot_height : hint_range(0.08, 0.4, 0.01) = 0.20;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float foot_contact(vec2 uv, float center_x, float expansion) {
	vec2 delta = vec2(
			(uv.x - center_x) / max(foot_width + expansion, 0.001),
			(uv.y - 0.54) / max(foot_height + expansion * 0.6, 0.001));
	return 1.0 - smoothstep(0.44, 1.0, length(delta));
}


void fragment() {
	vec2 cells = max(grid_cells, vec2(1.0));
	vec2 snapped_uv = (floor(UV * cells) + vec2(0.5)) / cells;
	float contact = max(
			foot_contact(snapped_uv, left_foot_x, 0.0),
			foot_contact(snapped_uv, right_foot_x, 0.0));
	float expanded = max(
			foot_contact(snapped_uv, left_foot_x, 0.035),
			foot_contact(snapped_uv, right_foot_x, 0.035));
	float wet_edge = max(0.0, expanded - contact);
	float alpha = clamp(
			contact * shadow_strength + wet_edge * wet_edge_strength,
			0.0,
			1.0);
	alpha = floor(alpha * alpha_levels + 0.5) / alpha_levels;
	if (alpha <= 0.001) {
		discard;
	}
	vec3 color = mix(wet_edge_color.rgb, shadow_color.rgb, contact);
	COLOR = vec4(color, alpha) * node_modulate;
}
