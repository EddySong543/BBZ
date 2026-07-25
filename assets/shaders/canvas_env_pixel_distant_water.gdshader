shader_type canvas_item;

// Calm water behind the bridge. This deliberately avoids screen-space
// reflections: the far channel is an atmospheric value band, while River owns
// the detailed reflections and motion in the foreground.

group_uniforms layout;
uniform vec2 size_px = vec2(2016.0, 162.0);
uniform float px_size : hint_range(1.0, 8.0) = 3.0;
group_uniforms;

group_uniforms palette;
uniform vec4 sky_color : source_color = vec4(0.55, 0.69, 0.73, 1.0);
uniform vec4 mid_color : source_color = vec4(0.32, 0.49, 0.55, 1.0);
uniform vec4 deep_color : source_color = vec4(0.14, 0.29, 0.36, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.68, 0.79, 0.78, 1.0);
uniform vec4 bank_shadow_color : source_color = vec4(0.08, 0.20, 0.24, 1.0);
group_uniforms;

group_uniforms sky_lane;
uniform float sky_lane_center : hint_range(0.0, 1.0) = 0.50;
uniform float sky_lane_half_width : hint_range(0.05, 0.5) = 0.24;
uniform float sky_lane_strength : hint_range(0.0, 0.7) = 0.30;
uniform float bank_shadow_width : hint_range(0.02, 0.4) = 0.18;
uniform float bank_shadow_strength : hint_range(0.0, 0.7) = 0.24;
group_uniforms;

group_uniforms motion;
uniform float anim_fps : hint_range(1.0, 12.0) = 4.0;
uniform float flow_speed_px : hint_range(-24.0, 24.0) = 6.0;
uniform float line_spacing_px : hint_range(4.0, 24.0) = 12.0;
uniform float line_density : hint_range(0.0, 0.6) = 0.18;
uniform float line_strength : hint_range(0.0, 0.8) = 0.26;
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 251.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	float t = floor(TIME * anim_fps) / anim_fps;
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;
	float depth = clamp(quv.y, 0.0, 1.0);

	vec3 col = mix(sky_color.rgb, mid_color.rgb, smoothstep(0.0, 0.62, depth));
	col = mix(col, deep_color.rgb, smoothstep(0.50, 1.0, depth));

	// A broad, quiet sky reflection widens slightly toward the viewer. It
	// creates the bright valley corridor visible through the bridge arches.
	float lane_width = sky_lane_half_width * mix(0.72, 1.18, depth);
	float lane_distance = abs(quv.x - sky_lane_center);
	float lane = 1.0 - smoothstep(lane_width, lane_width + 0.11, lane_distance);
	col = mix(col, sky_color.rgb * 1.06, lane * sky_lane_strength);

	// The side banks remain quieter and darker than the waterfall-fed opening.
	// This prevents the strip from reading as a uniformly luminous rectangle
	// behind the bridge.
	float side_distance = min(quv.x, 1.0 - quv.x);
	float bank_shadow = 1.0 - smoothstep(0.0, bank_shadow_width, side_distance);
	col = mix(col, bank_shadow_color.rgb, bank_shadow * bank_shadow_strength);

	// Only a few long, stable horizontal fragments move at a stepped cadence.
	// They provide depth without competing with the foreground River shader.
	float row_h = line_spacing_px + floor(depth * 2.0) * px_size;
	float row_id = floor(px.y / row_h);
	float row_line = 1.0 - step(px_size, mod(px.y, row_h));
	float cell_w = mix(92.0, 156.0, depth);
	float drift = t * flow_speed_px * mix(0.45, 0.8, depth);
	float shifted_x = px.x + drift + hash21(vec2(row_id, 19.0)) * cell_w;
	float cell_id = floor(shifted_x / cell_w);
	float cell_x = mod(shifted_x, cell_w);
	float active = step(1.0 - line_density, hash21(vec2(cell_id, row_id + 37.0)));
	float segment_length = mix(22.0, 62.0, hash21(vec2(cell_id + 11.0, row_id)));
	float segment = row_line * active * (1.0 - step(segment_length, cell_x));
	float line_fade = smoothstep(0.08, 0.28, depth) * (1.0 - smoothstep(0.78, 1.0, depth));
	col = mix(col, highlight_color.rgb, segment * line_fade * line_strength);

	// Quantize the final palette lightly so the strip stays compatible with
	// the scene's pixel-art value grouping.
	col = floor(col * 31.0 + 0.5) / 31.0;
	COLOR = vec4(col, 1.0);
}
