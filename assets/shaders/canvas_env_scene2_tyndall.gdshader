shader_type canvas_item;
render_mode unshaded, blend_add;

// Scene2-only pixel Tyndall shafts. The source stays outside the upper-right
// frame; three broken, stepped wedges lead the eye toward the waterfall.
uniform vec4 light_color : source_color = vec4(1.0, 0.90, 0.66, 1.0);
uniform float intensity : hint_range(0.0, 0.2, 0.001) = 0.05;
uniform vec2 source_uv = vec2(0.84, -0.08);
uniform vec2 landing_uv = vec2(0.43, 0.78);
uniform float top_width : hint_range(0.0, 0.2, 0.001) = 0.012;
uniform float bottom_width : hint_range(0.02, 0.5, 0.001) = 0.15;
uniform float pixel_size : hint_range(1.0, 12.0, 1.0) = 4.0;
uniform float band_count : hint_range(8.0, 80.0, 1.0) = 36.0;
uniform float break_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float phase_offset : hint_range(0.0, 20.0, 0.1) = 0.0;
uniform float start_fade : hint_range(0.0, 0.4, 0.01) = 0.04;
uniform float end_fade : hint_range(0.5, 1.2, 0.01) = 0.95;


float hash11(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453);
}


float shaft_mask(
		vec2 uv,
		float center_offset,
		float width_scale,
		float seed,
		float longitudinal_offset,
		float minimum_width) {
	float travel = landing_uv.y - source_uv.y;
	float t = (uv.y - source_uv.y) / max(travel, 0.001);
	float center_x = mix(source_uv.x, landing_uv.x + center_offset, t);
	float half_width = mix(top_width, bottom_width * width_scale, clamp(t, 0.0, 1.0));

	float band = floor((t + longitudinal_offset) * band_count);
	float edge_variation = (hash11(band + seed) - 0.5) * half_width * 0.34;
	float stepped_width = max(half_width + edge_variation, minimum_width);
	float edge = step(abs(uv.x - center_x), stepped_width);

	// Keep a faint continuous core while the outer body breaks into irregular
	// vertical intervals. This reads as air volume, not scanning stripes.
	float core = step(abs(uv.x - center_x), stepped_width * 0.38);
	float interval = mix(1.0 - break_strength, 1.0, hash11(band * 0.73 + seed * 2.1));
	float body = max(core * 0.62, edge * interval);

	float vertical = smoothstep(start_fade, start_fade + 0.12, t);
	vertical *= 1.0 - smoothstep(end_fade - 0.12, end_fade, t);
	return body * vertical * step(0.0, t) * step(t, 1.0);
}


void fragment() {
	vec2 viewport = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 grid = max(floor(viewport / pixel_size), vec2(1.0));
	vec2 uv = (floor(UV * grid) + vec2(0.5)) / grid;

	float slow_phase = floor(mod(TIME + phase_offset, 12.0) / 3.0);
	float breathe = 0.96 + slow_phase * 0.018;
	float minimum_width = 1.0 / grid.x;

	float shafts = 0.0;
	shafts += shaft_mask(uv, -0.115, 0.62, 3.0, 0.02, minimum_width) * 0.58;
	shafts += shaft_mask(uv, 0.0, 0.92, 17.0, 0.0, minimum_width);
	shafts += shaft_mask(uv, 0.13, 0.54, 41.0, -0.025, minimum_width) * 0.52;

	// Sparse 4 px-level translucency prevents a smooth vector-gradient look.
	float cell_noise = hash11(
			floor(uv.x * grid.x) * 0.19 +
			floor(uv.y * grid.y) * 0.37 +
			phase_offset);
	float alpha_step = mix(0.72, 1.0, step(0.48, cell_noise));
	float alpha = clamp(shafts * intensity * breathe * alpha_step, 0.0, 0.16);
	COLOR = vec4(light_color.rgb, alpha * light_color.a);
}
