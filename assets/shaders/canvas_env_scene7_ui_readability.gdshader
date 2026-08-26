shader_type canvas_item;
render_mode unshaded;

// Scene7 keeps the top HUD fully transparent to the bright authored sky.
// Bottom-control highlight compression remains isolated below.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec4 support_tint : source_color = vec4(0.13, 0.29, 0.35, 1.0);
uniform float hud_support_strength : hint_range(0.0, 0.4) = 0.0;
uniform float timer_support_strength : hint_range(0.0, 0.4) = 0.0;
uniform float horizontal_feather : hint_range(0.002, 0.04) = 0.018;
uniform float top_fade_start : hint_range(0.0, 0.15) = 0.055;
uniform float top_fade_end : hint_range(0.12, 0.35) = 0.225;
uniform float support_highlight_start : hint_range(0.0, 1.0) = 0.46;
uniform float support_highlight_end : hint_range(0.0, 1.0) = 0.82;
uniform float support_desaturation : hint_range(0.0, 0.2) = 0.0;

uniform float bottom_strength : hint_range(0.0, 1.0) = 0.42;
uniform float bottom_feather : hint_range(0.002, 0.08) = 0.028;
uniform float bottom_highlight_start : hint_range(0.0, 1.0) = 0.34;
uniform float bottom_highlight_end : hint_range(0.0, 1.0) = 0.70;
uniform float bottom_highlight_target : hint_range(0.1, 0.8) = 0.46;
uniform float bottom_desaturation : hint_range(0.0, 0.5) = 0.10;


float local_horizontal_mask(
		float point_x,
		float center_x,
		float half_width,
		float edge_softness) {
	return 1.0 - smoothstep(
			half_width,
			half_width + edge_softness,
			abs(point_x - center_x));
}


float top_falloff(float point_y) {
	return 1.0 - smoothstep(top_fade_start, top_fade_end, point_y);
}


float bottom_support_mask(vec2 point) {
	vec2 center = vec2(0.500, 0.895);
	vec2 half_size = vec2(0.215, 0.075);
	vec2 normalized_distance = abs(point - center) / half_size;
	float box_distance = max(normalized_distance.x, normalized_distance.y);
	return 1.0 - smoothstep(1.0, 1.0 + bottom_feather * 8.0, box_distance);
}


void fragment() {
	vec3 source = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float luma = dot(source, vec3(0.2126, 0.7152, 0.0722));

	float vertical_support = top_falloff(UV.y);
	float p1_support = local_horizontal_mask(
			UV.x, 0.205, 0.158, horizontal_feather) * vertical_support;
	float timer_support = local_horizontal_mask(
			UV.x, 0.500, 0.070, horizontal_feather) * vertical_support;
	float p2_support = local_horizontal_mask(
			UV.x, 0.795, 0.158, horizontal_feather) * vertical_support;
	float top_support = max(
			max(p1_support, p2_support) * hud_support_strength,
			timer_support * timer_support_strength);
	float support_gate = smoothstep(
			support_highlight_start, support_highlight_end, luma);
	float support_mix = top_support * support_gate;
	vec3 integrated = mix(source, support_tint.rgb, support_mix);
	float integrated_luma = dot(
			integrated, vec3(0.2126, 0.7152, 0.0722));
	integrated = mix(
			integrated,
			vec3(integrated_luma),
			support_mix * support_desaturation);

	// Bottom controls retain their accepted local highlight compression and are
	// deliberately independent from the redesigned top support fields.
	float bottom_mask = bottom_support_mask(UV) * bottom_strength;
	float bottom_gate = smoothstep(
			bottom_highlight_start, bottom_highlight_end, integrated_luma);
	float compressed_luma = min(integrated_luma, bottom_highlight_target);
	float bottom_luma_scale = compressed_luma / max(integrated_luma, 0.001);
	vec3 bottom_compressed = integrated * mix(
			1.0, bottom_luma_scale, bottom_mask * bottom_gate);
	float bottom_value = dot(
			bottom_compressed, vec3(0.2126, 0.7152, 0.0722));
	bottom_compressed = mix(
			bottom_compressed,
			vec3(bottom_value),
			bottom_mask * bottom_gate * bottom_desaturation);
	COLOR = vec4(bottom_compressed, 1.0);
}
