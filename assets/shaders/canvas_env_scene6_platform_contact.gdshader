shader_type canvas_item;
render_mode unshaded, blend_mix;

// A narrow, broken magma contact beneath Scene6's platform. It visually
// anchors the tiled rock shelf without drawing a ruler-straight bright edge.
uniform vec2 size_px = vec2(1552.0, 64.0);
uniform float pixel_size : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform vec4 shadow_color : source_color = vec4(0.025, 0.004, 0.010, 1.0);
uniform vec4 reflected_color : source_color = vec4(0.95, 0.16, 0.025, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float reflection_strength : hint_range(0.0, 0.5, 0.01) = 0.18;
uniform float reflection_coverage : hint_range(0.0, 0.5, 0.01) = 0.22;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash11(float value) {
	return fract(sin(value * 127.1) * 43758.5453);
}


void fragment() {
	vec2 px = floor(UV * size_px / pixel_size) * pixel_size;
	float segment = floor(px.x / 44.0);
	float segment_seed = hash11(segment + 31.7);
	float stepped_top = 8.0 + floor(hash11(segment + 9.2) * 3.0) * pixel_size;
	float shadow_depth = 16.0 + floor(segment_seed * 3.0) * pixel_size;

	float horizontal_fade = smoothstep(0.0, 32.0, px.x)
			* (1.0 - smoothstep(size_px.x - 32.0, size_px.x, px.x));
	float shadow = step(stepped_top, px.y)
			* (1.0 - step(stepped_top + shadow_depth, px.y))
			* horizontal_fade;

	float reflection_gate = step(1.0 - reflection_coverage, segment_seed);
	float reflected_line = step(stepped_top + shadow_depth, px.y)
			* (1.0 - step(stepped_top + shadow_depth + pixel_size, px.y))
			* reflection_gate
			* horizontal_fade;
	float alpha = max(shadow * shadow_strength, reflected_line * reflection_strength);
	vec3 color = mix(shadow_color.rgb, reflected_color.rgb, reflected_line);
	COLOR = vec4(color, alpha) * node_modulate;
}
