shader_type canvas_item;
render_mode blend_mix;

// Ref37 + Ref39 terrain-cell silhouette.
// Source textures stay full 60x60 squares. One runtime mask supplies the tiny
// gap, continuous dark outline and coarse-pixel rounded corner for every cell.
uniform float cell_px = 120.0;
uniform float cell_inset_px = 1.0;
uniform float corner_radius_px = 16.0;
uniform float pixel_step_px = 4.0;
uniform float border_px = 4.0;
uniform vec4 gap_color : source_color = vec4(0.125, 0.227, 0.200, 1.0);
uniform vec4 border_color : source_color = vec4(0.184, 0.271, 0.157, 1.0);

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


float pixel_rounded_box(vec2 cell_position, float inset_px, float radius_px) {
	vec2 size = vec2(cell_px - inset_px * 2.0);
	vec2 p = cell_position - vec2(inset_px);
	float inside = step(0.0, p.x) * step(p.x, size.x)
			* step(0.0, p.y) * step(p.y, size.y);

	// Quantize the distance from the nearest edge, not the coordinate measured
	// from the top-left. The 118px inner size has a 2px remainder on a 4px grid;
	// nearest-edge quantization keeps that remainder centered and makes all four
	// coarse-pixel corners exact mirrors of one another.
	vec2 raw_edge = min(p, size - p);
	vec2 edge = (floor(max(raw_edge, vec2(0.0)) / pixel_step_px) + 0.5) * pixel_step_px;
	vec2 corner = vec2(radius_px) - edge;
	float rounded = 1.0;
	if (corner.x > 0.0 && corner.y > 0.0 && length(corner) > radius_px) {
		rounded = 0.0;
	}
	return inside * rounded;
}


void fragment() {
	vec2 cell_position = mod(local_position, vec2(cell_px));
	float outer = pixel_rounded_box(cell_position, cell_inset_px, corner_radius_px);
	float inner = pixel_rounded_box(
			cell_position,
			cell_inset_px + border_px,
			max(corner_radius_px - border_px, pixel_step_px));

	if (outer < 0.5) {
		COLOR = gap_color;
	} else if (inner < 0.5) {
		COLOR = border_color;
	}
}
