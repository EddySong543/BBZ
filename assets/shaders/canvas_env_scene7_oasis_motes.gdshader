shader_type canvas_item;
render_mode unshaded, blend_mix;

// Three Scene7 instances share this shader, but each material represents one
// physical depth plane. Particles move independently inside stable spatial
// cells so the layer never reads as one texture sheet sliding across the view.

group_uniforms palette;
uniform vec4 jade_color : source_color = vec4(0.35, 0.86, 0.72, 1.0);
uniform vec4 gold_color : source_color = vec4(0.84, 0.48, 0.76, 1.0);
uniform float accent_ratio : hint_range(0.0, 0.5) = 0.14;
uniform float alpha : hint_range(0.0, 0.6) = 0.30;
group_uniforms;

group_uniforms layout;
uniform vec2 pixel_grid = vec2(992.0, 200.0);
uniform vec2 macro_cell = vec2(96.0, 64.0);
uniform float density : hint_range(0.0, 1.0) = 0.56;
uniform float secondary_density : hint_range(0.0, 0.5) = 0.20;
uniform float spark_length_px : hint_range(0.0, 2.0) = 1.0;
uniform float spark_chance : hint_range(0.0, 0.5) = 0.16;
uniform float cross_glow_px : hint_range(0.0, 2.0) = 1.0;
uniform float cross_glow_strength : hint_range(0.0, 1.0) = 0.58;
group_uniforms;

group_uniforms motion;
uniform float rise_px_per_sec : hint_range(0.0, 8.0) = 2.4;
uniform float horizontal_sway_px : hint_range(0.0, 6.0) = 2.0;
uniform float cycle_sec : hint_range(5.0, 20.0) = 11.6;
uniform float motion_fps : hint_range(4.0, 20.0) = 10.0;
uniform float twinkle_speed : hint_range(0.0, 2.0) = 0.46;
uniform float phase = 0.0;
uniform float diagnostic_time_sec = -1.0;
group_uniforms;


float hash21(vec2 value) {
	value = mod(value, vec2(509.0, 251.0));
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


float motion_time() {
	return diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
}


float wrapped_axis_distance(float first, float second, float span) {
	float direct = abs(first - second);
	return min(direct, max(span - direct, 0.0));
}


vec4 mote_sample(
		vec2 local_cell,
		vec2 macro,
		float stepped_time,
		vec2 salt,
		float presence) {
	float seed_active = hash21(macro * 1.73 + salt + vec2(phase, phase * 0.37));
	float active = step(1.0 - presence, seed_active);
	float seed_x = hash21(macro * 2.11 + salt.yx + vec2(13.7, 4.1));
	float seed_y = hash21(macro * 2.63 + salt + vec2(3.2, 17.9));
	float seed_speed = hash21(macro * 3.17 + salt.yx + vec2(29.3, 8.6));
	float seed_shape = hash21(macro * 3.71 + salt + vec2(6.4, 31.2));
	float seed_color = hash21(macro * 4.13 + salt.yx + vec2(41.8, 11.5));

	float local_cycle = cycle_sec * mix(0.82, 1.18, seed_speed);
	float life = fract(stepped_time / max(local_cycle, 0.001)
			+ seed_y + phase * 0.071);
	float travel_px = max(rise_px_per_sec * local_cycle, 4.0);
	float base_x = floor(mix(0.12, 0.88, seed_x) * macro_cell.x);
	float base_y = floor(mix(0.18, 0.92, seed_y) * macro_cell.y);
	float sway_period = mix(6.8, 12.4, seed_x);
	float sway = sin(stepped_time * 6.2831853 / sway_period
			+ seed_active * 6.2831853 + phase);
	sway = floor(sway * horizontal_sway_px + 0.5);
	float center_x = mod(base_x + sway + macro_cell.x, macro_cell.x);
	float center_y = mod(
			floor(base_y - life * travel_px) + macro_cell.y * 2.0,
			macro_cell.y);

	float dx = wrapped_axis_distance(local_cell.x, center_x, macro_cell.x);
	float dy = wrapped_axis_distance(local_cell.y, center_y, macro_cell.y);
	float core = step(max(dx, dy), 0.1);
	float use_spark = step(1.0 - spark_chance, seed_shape);
	float horizontal_spark = step(dy, 0.1)
			* step(dx, spark_length_px) * use_spark;
	float shape = max(core, horizontal_spark);
	float horizontal_cross = step(dy, 0.1) * step(dx, cross_glow_px);
	float vertical_cross = step(dx, 0.1) * step(dy, cross_glow_px);
	float mote_halo = max(horizontal_cross, vertical_cross) * (1.0 - shape);

	float life_fade = smoothstep(0.0, 0.08, life)
			* (1.0 - smoothstep(0.91, 1.0, life));
	float twinkle_phase = stepped_time * twinkle_speed
			+ seed_color * 6.2831853 + phase;
	float twinkle = floor(
			(0.5 + 0.5 * sin(twinkle_phase)) * 3.0 + 0.5) / 3.0;
	float brightness = mix(0.78, 1.0, twinkle) * life_fade;
	float accent = step(1.0 - accent_ratio, seed_color);
	return vec4(
			shape * active * brightness,
			accent,
			life,
			mote_halo * active * brightness);
}


void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	vec2 macro = floor(cell / macro_cell);
	vec2 local_cell = mod(cell, macro_cell);
	float stepped_time = floor(motion_time() * motion_fps)
			/ max(motion_fps, 1.0);

	vec4 primary = mote_sample(
			local_cell, macro, stepped_time, vec2(5.3, 19.7), density);
	vec4 secondary = mote_sample(
			local_cell, macro, stepped_time, vec2(37.1, 7.9), secondary_density);
	float selected_secondary = step(primary.x, secondary.x);
	float mote = max(primary.x, secondary.x);
	float mote_halo = max(primary.w, secondary.w);
	float accent = mix(primary.y, secondary.y, selected_secondary);

	float vertical_fade = smoothstep(0.0, 0.10, UV.y)
			* (1.0 - smoothstep(0.88, 1.0, UV.y));
	vec3 mote_color = mix(jade_color.rgb, gold_color.rgb, accent);
	float visible_mote = clamp(
			mote + mote_halo * cross_glow_strength, 0.0, 1.0);
	COLOR = vec4(mote_color, visible_mote * vertical_fade * alpha);
}
