shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 node_offset = vec2(0.0);
uniform vec2 group_size = vec2(288.0, 40.0);
uniform float group_center_y = 20.0;
uniform float perspective_strength : hint_range(0.0, 0.35, 0.01) = 0.10;
uniform float slope_pixels : hint_range(-16.0, 16.0, 0.1) = 2.5;


void vertex() {
	float safe_group_width = max(group_size.x, 1.0);
	float group_x = node_offset.x + VERTEX.x;
	float projected_x = clamp(
			group_x / safe_group_width,
			0.0,
			1.0);
	float vertical_scale = (
			1.0
			- perspective_strength * projected_x);
	float group_y = node_offset.y + VERTEX.y;
	float projected_y = (
			group_center_y
			+ (group_y - group_center_y) * vertical_scale
			+ slope_pixels * projected_x);
	VERTEX.y = projected_y - node_offset.y;
}
