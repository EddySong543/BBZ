shader_type canvas_item;

// A restrained, pixel-stepped contact shade for the two bridge ends. It is a
// child of StoneBridge, so editor changes to the bridge transform keep the
// transition aligned without coupling scene logic to authored coordinates.

uniform vec2 size_px = vec2(1999.0, 385.0);
uniform float px_size : hint_range(1.0, 8.0) = 4.0;
uniform float left_reach : hint_range(0.05, 0.4) = 0.19;
uniform float right_reach : hint_range(0.6, 0.95) = 0.83;
uniform float contour_wobble : hint_range(0.0, 0.08) = 0.025;
uniform float shadow_strength : hint_range(0.0, 0.7) = 0.24;
uniform vec4 upper_shadow_color : source_color = vec4(0.16, 0.24, 0.18, 1.0);
uniform vec4 lower_shadow_color : source_color = vec4(0.07, 0.15, 0.17, 1.0);


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 251.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;
	float row = floor(px.y / max(px_size * 4.0, 1.0));
	float row_wobble = (hash21(vec2(row, 71.0)) - 0.5) * contour_wobble;

	float left_bank = 1.0 - smoothstep(
			left_reach + row_wobble,
			left_reach + 0.07 + row_wobble,
			quv.x);
	float right_bank = smoothstep(
			right_reach - 0.07 + row_wobble,
			right_reach + row_wobble,
			quv.x);
	float bank = max(left_bank, right_bank);

	// Keep the playable turf rim readable. The darker contact grows below it,
	// tying the masonry to side cliffs and the water rather than painting a
	// heavy vignette over the character platform.
	float vertical_weight = mix(0.32, 1.0, smoothstep(0.18, 0.82, quv.y));
	float inner_cell = hash21(floor(px / vec2(px_size * 5.0, px_size * 4.0)));
	float broken_inner_edge = mix(0.72, 1.0, step(0.42, inner_cell));
	float alpha = bank * vertical_weight * broken_inner_edge * shadow_strength;
	vec3 shade = mix(upper_shadow_color.rgb, lower_shadow_color.rgb, quv.y);

	COLOR = vec4(shade, alpha);
}
