shader_type canvas_item;
render_mode unshaded, blend_mix;

// Pixel-stable heat haze and sparse embers behind the fighters. This is a
// local authored atmosphere pass: it never samples or distorts the screen.
uniform vec2 size_px = vec2(1680.0, 420.0);
uniform float pixel_size : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform vec4 mist_color : source_color = vec4(0.55, 0.08, 0.06, 1.0);
uniform float mist_strength : hint_range(0.0, 0.2, 0.005) = 0.055;
uniform vec4 smoke_color : source_color = vec4(0.28, 0.035, 0.045, 1.0);
uniform float smoke_strength : hint_range(0.0, 0.12, 0.005) = 0.0;
uniform float smoke_rise_speed : hint_range(0.0, 0.08, 0.001) = 0.018;
uniform float smoke_scale : hint_range(2.0, 12.0, 0.1) = 5.2;
uniform float smoke_center_width : hint_range(0.08, 0.5, 0.01) = 0.34;
uniform float smoke_layout : hint_range(-1.0, 1.0, 1.0) = 1.0;
uniform vec4 ember_color : source_color = vec4(1.0, 0.37, 0.08, 1.0);
uniform vec4 ember_edge_color : source_color = vec4(0.72, 0.12, 0.025, 1.0);
uniform float ember_strength : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float ember_density : hint_range(0.0, 0.5, 0.01) = 0.18;
uniform float ember_rise_speed : hint_range(0.0, 48.0, 1.0) = 22.0;
uniform float ember_horizontal_drift : hint_range(-0.2, 0.2, 0.01) = 0.06;
uniform float phase_seed = 17.0;
uniform float motion_feather : hint_range(0.0, 0.45, 0.01) = 0.18;
uniform float source_bias_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 local = fract(value);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float pixel_at(vec2 delta_cells, vec2 target_cell) {
	vec2 distance_to_cell = abs(delta_cells - target_cell);
	return (1.0 - step(0.5, distance_to_cell.x))
			* (1.0 - step(0.5, distance_to_cell.y));
}


float ember_field(vec2 px, float rise_px) {
	vec2 field_px = vec2(
			px.x + rise_px * ember_horizontal_drift,
			px.y + rise_px);
	vec2 cell_size = vec2(92.0, 116.0);
	vec2 cell = floor(field_px / cell_size);
	vec2 local = mod(field_px, cell_size);
	float seed = hash21(cell + vec2(phase_seed, phase_seed * 0.37));
	float gate = step(1.0 - ember_density, seed);
	vec2 ember_center = vec2(
			12.0 + hash21(cell + 43.2) * (cell_size.x - 24.0),
			16.0 + hash21(cell + 91.6) * (cell_size.y - 32.0));
	ember_center = floor(ember_center / pixel_size) * pixel_size;
	vec2 ember_delta_cells = (local - ember_center) / pixel_size;
	// Each spark is a tiny asymmetrical shard: one hot source pixel, one dim
	// trailing pixel, and an occasional faint tip. This avoids the rejected
	// oversized circles while staying readable at the authored pixel scale.
	float shape_seed = hash21(cell + vec2(71.3, phase_seed * 1.91));
	float tail_shift = -1.0
			+ step(0.34, shape_seed)
			+ step(0.68, shape_seed);
	float tip_gate = step(0.58, hash21(cell + vec2(18.7, 63.4)));
	float hot_core = pixel_at(ember_delta_cells, vec2(0.0));
	float warm_tail = pixel_at(
			ember_delta_cells, vec2(tail_shift, 1.0)) * 0.34;
	float faint_tip = pixel_at(
			ember_delta_cells, vec2(0.0, -1.0)) * tip_gate * 0.48;
	float irregular_ember = max(hot_core, max(warm_tail, faint_tip));
	return gate * irregular_ember;
}


void fragment() {
	vec2 px = floor(UV * size_px / pixel_size) * pixel_size;
	vec2 uv_px = px / size_px;

	float drift = TIME * 0.012;
	float broad = value_noise(vec2(uv_px.x * 5.0 + drift, uv_px.y * 7.0));
	float fine = value_noise(vec2(uv_px.x * 11.0 - drift * 0.63, uv_px.y * 13.0));
	float mist_density = smoothstep(0.42, 0.72, broad * 0.72 + fine * 0.28);
	float mist_band = smoothstep(0.62, 0.76, uv_px.y)
			* (1.0 - smoothstep(0.88, 1.0, uv_px.y));
	float side_fade = smoothstep(0.0, 0.08, uv_px.x)
			* (1.0 - smoothstep(0.92, 1.0, uv_px.x));
	float mist = mist_density * mist_band * side_fade * mist_strength;

	// One very slow, broken heat-smoke contour rises from the central forge
	// valley. It is pixel-stable in space and never fills the negative space
	// with a soft translucent blanket.
	float smoke_rise = TIME * smoke_rise_speed;
	float smoke_broad = value_noise(vec2(
			uv_px.x * smoke_scale + smoke_rise * 0.27,
			uv_px.y * smoke_scale * 1.34 + smoke_rise));
	float smoke_detail = value_noise(vec2(
			uv_px.x * smoke_scale * 2.1 - smoke_rise * 0.19,
			uv_px.y * smoke_scale * 2.7 + smoke_rise * 1.41));
	float smoke_field = smoke_broad * 0.76 + smoke_detail * 0.24;
	float smoke_contour = smoothstep(0.54, 0.67, smoke_field)
			* (1.0 - smoothstep(0.71, 0.82, smoke_field));
	float smoke_vertical = smoothstep(0.40, 0.64, uv_px.y)
			* (1.0 - smoothstep(0.88, 1.0, uv_px.y));
	float smoke_center = 1.0 - smoothstep(
			smoke_center_width,
			min(smoke_center_width + 0.14, 0.50),
			abs(uv_px.x - 0.5));
	float smoke_sides = 1.0 - smoke_center;
	float smoke_layout_mask = mix(
			smoke_sides,
			smoke_center,
			step(0.0, smoke_layout));
	float smoke = smoke_contour * smoke_vertical * smoke_layout_mask
			* smoke_strength;

	float travel = TIME * ember_rise_speed;
	float phase = travel / pixel_size;
	float current_travel = floor(phase) * pixel_size;
	float next_travel = current_travel + pixel_size;
	float blend_phase = smoothstep(
			motion_feather,
			1.0 - motion_feather,
			fract(phase));
	float ember_shape = mix(
			ember_field(px, current_travel),
			ember_field(px, next_travel),
			blend_phase);
	float vertical_spawn_fade = smoothstep(0.12, 0.45, uv_px.y)
			* (1.0 - smoothstep(0.84, 0.98, uv_px.y));
	float source_field = value_noise(vec2(
			uv_px.x * 7.0 + phase_seed * 0.11,
			uv_px.y * 4.0 + phase_seed * 0.03));
	float lower_source = smoothstep(0.38, 0.88, uv_px.y);
	float fissure_source = smoothstep(0.46, 0.72, source_field);
	float source_coherence = mix(
			1.0,
			mix(0.48, 1.28, lower_source * fissure_source),
			source_bias_strength);
	float ember_alpha = ember_shape * vertical_spawn_fade
			* side_fade * ember_strength * source_coherence;

	vec3 ember_tint = mix(
			ember_edge_color.rgb, ember_color.rgb, step(0.70, ember_shape));
	float atmosphere_alpha = max(mist, smoke);
	vec3 atmosphere_tint = mix(
			mist_color.rgb, smoke_color.rgb, step(mist, smoke));
	vec3 color = mix(
			atmosphere_tint,
			ember_tint,
			step(atmosphere_alpha, ember_alpha));
	COLOR = vec4(color, max(atmosphere_alpha, ember_alpha)) * node_modulate;
}
