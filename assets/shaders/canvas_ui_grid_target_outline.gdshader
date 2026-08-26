shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float cell_px = 120.0;
uniform float cell_inset_px = 1.0;
uniform float corner_radius_px = 16.0;
uniform float pixel_step_px = 4.0;
uniform float outline_px = 4.0;
uniform float outline_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.10;
uniform vec4 target_color : source_color = vec4(1.0, 0.88, 0.63, 1.0);

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


float pixel_rounded_box(vec2 cell_position, float inset_px, float radius_px) {
	vec2 size = vec2(cell_px - inset_px * 2.0);
	vec2 p = cell_position - vec2(inset_px);
	float inside = step(0.0, p.x) * step(p.x, size.x)
			* step(0.0, p.y) * step(p.y, size.y);
	vec2 raw_edge = min(p, size - p);
	vec2 edge = (floor(max(raw_edge, vec2(0.0)) / pixel_step_px) + 0.5)
			* pixel_step_px;
	vec2 corner = vec2(radius_px) - edge;
	float rounded = 1.0;
	if (corner.x > 0.0 && corner.y > 0.0 && length(corner) > radius_px) {
		rounded = 0.0;
	}
	return inside * rounded;
}


void fragment() {
	float outer = pixel_rounded_box(
			local_position, cell_inset_px, corner_radius_px);
	float inner = pixel_rounded_box(
			local_position,
			cell_inset_px + outline_px,
			max(corner_radius_px - outline_px, pixel_step_px));
	float outline = outer * (1.0 - inner);
	float fill = inner * fill_alpha;
	COLOR = vec4(target_color.rgb,
			target_color.a * clamp(outline * outline_alpha + fill, 0.0, 1.0));
}
