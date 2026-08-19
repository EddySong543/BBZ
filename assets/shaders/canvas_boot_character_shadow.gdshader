shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 pointer_tilt = vec2(0.0);
uniform vec2 perspective_pivot = vec2(0.56, 0.50);
uniform float pointer_yaw_strength : hint_range(0.0, 0.12, 0.001) = 0.052;
uniform float pointer_pitch_strength : hint_range(0.0, 0.08, 0.001) = 0.021;
uniform float front_hand_start : hint_range(0.5, 0.9, 0.01) = 0.62;
uniform float front_hand_depth_boost : hint_range(1.0, 1.6, 0.01) = 1.25;
uniform vec4 shadow_color : source_color = vec4(
		0.0313725, 0.0392157, 0.0509804, 0.82);

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


vec2 perspective_source_uv(vec2 display_uv) {
	vec2 local_uv = display_uv - perspective_pivot;
	float front_mask = smoothstep(
			front_hand_start,
			0.98,
			display_uv.x);
	float depth_axis = local_uv.x * mix(
			1.0,
			front_hand_depth_boost,
			front_mask);
	float pointer_scale = max(
			1.0
				+ depth_axis
					* pointer_tilt.x
					* pointer_yaw_strength
				+ local_uv.y
					* pointer_tilt.y
					* pointer_pitch_strength,
			0.88);
	return perspective_pivot + local_uv / pointer_scale;
}


void fragment() {
	vec2 source_uv = perspective_source_uv(UV);
	bool inside_bounds = (
			source_uv.x >= 0.0
			&& source_uv.x <= 1.0
			&& source_uv.y >= 0.0
			&& source_uv.y <= 1.0);
	float bounds_mask = float(inside_bounds);
	source_uv = clamp(source_uv, vec2(0.0), vec2(1.0));
	vec4 sampled = texture(TEXTURE, source_uv);
	COLOR = vec4(
			shadow_color.rgb,
			sampled.a * shadow_color.a * bounds_mask) * vertex_color;
}
