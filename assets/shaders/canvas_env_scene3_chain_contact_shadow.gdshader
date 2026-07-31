shader_type canvas_item;
render_mode unshaded, blend_mix;

// Two short, pixel-stepped foot contacts replace the broad ground ellipse.
// A subtle repeated breakup keeps the shadow attached to individual links.
uniform vec4 shadow_color : source_color = vec4(0.015, 0.045, 0.045, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform vec2 grid_cells = vec2(44.0, 12.0);
uniform float alpha_levels : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float left_foot_x : hint_range(0.2, 0.5, 0.01) = 0.41;
uniform float right_foot_x : hint_range(0.5, 0.8, 0.01) = 0.63;
uniform float foot_width : hint_range(0.08, 0.3, 0.01) = 0.16;
uniform float foot_height : hint_range(0.08, 0.4, 0.01) = 0.22;
uniform float link_cells : hint_range(2.0, 10.0, 1.0) = 6.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float foot_contact(vec2 uv, float center_x) {
	vec2 delta = vec2(
			(uv.x - center_x) / max(foot_width, 0.001),
			(uv.y - 0.56) / max(foot_height, 0.001));
	return 1.0 - smoothstep(0.45, 1.0, length(delta));
}


void fragment() {
	vec2 cells = max(grid_cells, vec2(1.0));
	vec2 snapped_uv = (floor(UV * cells) + vec2(0.5)) / cells;
	float left_foot = foot_contact(snapped_uv, left_foot_x);
	float right_foot = foot_contact(snapped_uv, right_foot_x);
	float paired_contact = max(left_foot, right_foot);
	float link_phase = fract(snapped_uv.x * link_cells + 0.16);
	float link_break = smoothstep(0.04, 0.22, link_phase)
			* (1.0 - smoothstep(0.76, 0.96, link_phase));
	float link_shaped_contact = paired_contact * mix(0.62, 1.0, link_break);
	float alpha = floor(
			clamp(link_shaped_contact * shadow_strength, 0.0, 1.0)
			* alpha_levels + 0.5
	) / alpha_levels;
	if (alpha <= 0.001) {
		discard;
	}
	COLOR = vec4(shadow_color.rgb, alpha * shadow_color.a) * node_modulate;
}
