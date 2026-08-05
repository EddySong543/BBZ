shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene4 reuses Scene2's bottom fog-band role, but owns a denser pixel-cloud
// silhouette and forest-specific palette. The fog fills the empty lower
// foreground while its crest drifts horizontally above the UI-safe region.
uniform vec4 fog_color : source_color = vec4(0.43, 0.56, 0.54, 1.0);
uniform vec4 fog_light_color : source_color = vec4(0.62, 0.70, 0.68, 1.0);
uniform float alpha_max : hint_range(0.0, 0.6, 0.01) = 0.30;
uniform float drift_speed : hint_range(0.0, 0.08, 0.001) = 0.024;
uniform float scale_x : hint_range(0.5, 6.0, 0.1) = 2.4;
uniform float crest_y : hint_range(0.05, 0.5, 0.01) = 0.16;
uniform vec2 pixel_grid = vec2(240.0, 50.0);


void fragment() {
	vec2 grid = max(pixel_grid, vec2(1.0));
	vec2 uvq = (floor(UV * grid) + vec2(0.5)) / grid;
	float t = TIME * drift_speed * TAU;

	// Three incommensurate waves avoid a single repeating sine silhouette.
	float broad = sin(uvq.x * TAU * scale_x + t);
	float folding = sin(
			uvq.x * TAU * scale_x * 0.57 - t * 0.73 + 1.7);
	float small = sin(
			uvq.x * TAU * scale_x * 1.83 + t * 0.41 + 3.2);
	float crest = crest_y + broad * 0.065
			+ folding * 0.045 + small * 0.018;

	// A solid lower body closes the foreground hole. The stepped transition
	// keeps the upper edge cloud-like without soft vector-style blur.
	float body = smoothstep(crest - 0.025, crest + 0.055, uvq.y);
	float crest_band = body * (
			1.0 - smoothstep(crest + 0.045, crest + 0.16, uvq.y));

	// Independent internal drift prevents the filled body from reading as one
	// flat translucent rectangle.
	float inner_a = sin(
			uvq.x * TAU * (scale_x * 1.31) - t * 0.61
			+ uvq.y * TAU * 2.0);
	float inner_b = sin(
			uvq.x * TAU * (scale_x * 0.43) + t * 0.47
			- uvq.y * TAU * 3.0);
	float density = clamp(
			0.76 + inner_a * 0.12 + inner_b * 0.08,
			0.56,
			0.96);
	density = floor(density * 5.0 + 0.5) / 5.0;

	vec3 color = mix(
			fog_color.rgb,
			fog_light_color.rgb,
			crest_band * 0.52);
	float alpha = alpha_max * body * density;
	COLOR = vec4(color, alpha);
}
