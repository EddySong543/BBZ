shader_type canvas_item;
render_mode unshaded, blend_mix;

// Medium-depth charred flakes. Motion is interpolated between pixel phases so
// the approved slow rise stays smooth without turning into bright sparks.
uniform vec2 size_px = vec2(1680.0, 560.0);
uniform float pixel_size : hint_range(2.0, 6.0, 1.0) = 3.0;
uniform vec2 cell_size = vec2(64.0, 78.0);
uniform vec4 ash_color : source_color = vec4(0.42, 0.105, 0.045, 1.0);
uniform vec4 ash_shadow_color : source_color = vec4(0.16, 0.018, 0.028, 1.0);
uniform float ash_strength : hint_range(0.0, 1.0, 0.01) = 0.60;
uniform float ash_density : hint_range(0.0, 0.5, 0.01) = 0.23;
uniform float rise_speed_px : hint_range(1.0, 24.0, 0.5) = 8.0;
uniform float horizontal_drift : hint_range(-0.2, 0.2, 0.01) = -0.055;
uniform float phase_seed = 43.0;
uniform float motion_feather : hint_range(0.0, 0.45, 0.01) = 0.18;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


float pixel_at(vec2 delta_cells, vec2 target_cell) {
	vec2 distance_to_cell = abs(delta_cells - target_cell);
	return (1.0 - step(0.5, distance_to_cell.x))
			* (1.0 - step(0.5, distance_to_cell.y));
}


float ash_field(vec2 px, float rise_px, out float shade) {
	vec2 field_px = vec2(px.x + rise_px * horizontal_drift, px.y + rise_px);
	vec2 cell = floor(field_px / cell_size);
	vec2 local = mod(field_px, cell_size);
	float seed = hash21(cell + vec2(phase_seed, phase_seed * 0.37));
	float gate = step(1.0 - ash_density, seed);
	vec2 center = vec2(
			10.0 + hash21(cell + 31.7) * (cell_size.x - 20.0),
			12.0 + hash21(cell + 83.1) * (cell_size.y - 24.0));
	center = floor(center / pixel_size) * pixel_size;
	vec2 delta = (local - center) / pixel_size;
	float lean = -1.0 + step(0.5, hash21(cell + vec2(19.3, 71.2))) * 2.0;
	float short_flake = step(0.48, hash21(cell + vec2(62.4, 14.9)));
	float body = pixel_at(delta, vec2(0.0));
	body = max(body, pixel_at(delta, vec2(lean, 0.0)) * 0.82);
	body = max(body, pixel_at(delta, vec2(0.0, 1.0)) * 0.68);
	body = max(body, pixel_at(delta, vec2(-lean, -1.0)) * short_flake * 0.52);
	shade = hash21(cell + vec2(7.3, 97.6));
	return gate * body;
}


void fragment() {
	vec2 px = floor(UV * size_px / pixel_size) * pixel_size;
	vec2 uv_px = px / size_px;
	float travel = TIME * rise_speed_px;
	float phase = travel / pixel_size;
	float current_travel = floor(phase) * pixel_size;
	float next_travel = current_travel + pixel_size;
	float current_shade = 0.0;
	float next_shade = 0.0;
	float current_shape = ash_field(px, current_travel, current_shade);
	float next_shape = ash_field(px, next_travel, next_shade);
	float blend_phase = smoothstep(
			motion_feather, 1.0 - motion_feather, fract(phase));
	float shape = mix(current_shape, next_shape, blend_phase);
	float shade = mix(current_shade, next_shade, blend_phase);
	float vertical_fade = smoothstep(0.08, 0.22, uv_px.y)
			* (1.0 - smoothstep(0.82, 0.98, uv_px.y));
	float side_fade = smoothstep(0.0, 0.05, uv_px.x)
			* (1.0 - smoothstep(0.95, 1.0, uv_px.x));
	float alpha = shape * vertical_fade * side_fade * ash_strength;
	vec3 tint = mix(ash_shadow_color.rgb, ash_color.rgb, 0.38 + shade * 0.42);
	COLOR = vec4(tint, alpha) * node_modulate;
}
