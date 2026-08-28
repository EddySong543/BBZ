shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 pointer_tilt = vec2(0.0);
uniform vec2 perspective_pivot = vec2(0.56, 0.50);
uniform float pointer_yaw_strength : hint_range(0.0, 0.12, 0.001) = 0.052;
uniform float pointer_pitch_strength : hint_range(0.0, 0.08, 0.001) = 0.021;
uniform float front_hand_start : hint_range(0.5, 0.9, 0.01) = 0.62;
uniform float front_hand_depth_boost : hint_range(1.0, 1.6, 0.01) = 1.25;
uniform float blue_replacement_strength : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform vec4 blue_shadow_target : source_color = vec4(0.188235, 0.196078, 0.207843, 1.0);
uniform vec4 blue_highlight_target : source_color = vec4(0.466667, 0.450980, 0.419608, 1.0);

varying vec4 vertex_color;


vec3 replace_blue_cloth_family(vec3 sampled_color) {
	float luminance = dot(sampled_color, vec3(0.299, 0.587, 0.114));
	float blue_dominance = sampled_color.b - max(sampled_color.r, sampled_color.g);
	float blue_mask = smoothstep(0.025, 0.085, blue_dominance);
	float value_position = smoothstep(0.10, 0.62, luminance);
	vec3 graphite = mix(
			blue_shadow_target.rgb,
			blue_highlight_target.rgb,
			value_position);
	return mix(
			sampled_color,
			graphite,
			blue_mask * clamp(blue_replacement_strength, 0.0, 1.0));
}


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
	if (!inside_bounds) {
		COLOR = vec4(0.0);
	} else {
		vec4 source = texture(TEXTURE, source_uv);
		source.rgb = replace_blue_cloth_family(source.rgb);
		COLOR = source * vertex_color;
	}
}
