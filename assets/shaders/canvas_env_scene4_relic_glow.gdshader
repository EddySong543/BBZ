shader_type canvas_item;
render_mode unshaded;

// Scene4 ruin stones stay inside the forest palette while one restrained
// energy family climbs through right-angle channels cut into the slab.
// The channel is shaded as part of the stone instead of a line drawn over it.
uniform vec4 shadow_color : source_color = vec4(0.025, 0.12, 0.09, 1.0);
uniform vec4 mid_color : source_color = vec4(0.16, 0.38, 0.25, 1.0);
uniform vec4 light_color : source_color = vec4(0.48, 0.70, 0.38, 1.0);
uniform vec4 rune_color : source_color = vec4(0.62, 0.79, 0.94, 1.0);
uniform vec4 rune_core_color : source_color = vec4(0.82, 0.92, 1.0, 1.0);
uniform float exposure : hint_range(0.5, 2.0, 0.01) = 1.18;
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float rune_threshold : hint_range(0.0, 0.8, 0.01) = 0.22;
uniform float rune_softness : hint_range(0.01, 0.4, 0.01) = 0.16;
uniform float glow_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float pulse_speed : hint_range(0.0, 3.0, 0.01) = 0.52;
uniform float pulse_phase : hint_range(0.0, 6.3, 0.01) = 0.0;
uniform float circuit_width_px : hint_range(0.08, 0.8, 0.01) = 0.18;
uniform float circuit_tail : hint_range(0.08, 0.45, 0.01) = 0.24;
uniform float base_charge : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float energy_pixel_size_px : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform float motion_feather : hint_range(0.01, 0.12, 0.005) = 0.055;
// Click feedback highlights only energy that is already moving through the
// route. It never illuminates the dormant circuit or changes travel timing.
uniform float interaction_flash : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float interaction_flash_gain : hint_range(0.5, 2.0, 0.01) = 1.28;
// Scene achievement feedback uses one tail-extension envelope and one light
// envelope. The extension starts at each moving head and grows backward along
// its existing path; neither value changes clocks, drift, or head positions.
uniform float achievement_sync : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float achievement_glow : hint_range(0.0, 1.0, 0.01) = 0.0;

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


float hash11(float value) {
	return fract(sin(value * 91.3458 + 17.217) * 47453.5453);
}


float vertical_segment(
		vec2 uv,
		float x,
		float y_top,
		float y_bottom,
		float width_px,
		vec2 pixel_size) {
	float snapped_x = (
			floor(x / pixel_size.x) + 0.5
	) * pixel_size.x;
	float across = abs(uv.x - snapped_x) / pixel_size.x;
	float line = 1.0 - smoothstep(width_px, width_px + 0.10, across);
	return line * step(y_top, uv.y) * step(uv.y, y_bottom);
}


float horizontal_segment(
		vec2 uv,
		float y,
		float x_left,
		float x_right,
		float width_px,
		vec2 pixel_size) {
	float snapped_y = (
			floor(y / pixel_size.y) + 0.5
	) * pixel_size.y;
	float across = abs(uv.y - snapped_y) / pixel_size.y;
	float line = 1.0 - smoothstep(width_px, width_px + 0.10, across);
	return line * step(x_left, uv.x) * step(uv.x, x_right);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float value = smoothstep(0.015, 0.42, luma * exposure);

	vec3 palette = mix(
			shadow_color.rgb,
			mid_color.rgb,
			smoothstep(0.0, 0.68, value));
	palette = mix(
			palette,
			light_color.rgb,
			smoothstep(0.60, 1.0, value));
	vec3 color = mix(source.rgb * exposure, palette, palette_strength);

	// Quantize only the energy layer into larger authored-pixel blocks. The
	// stone texture itself is untouched, while the circuit reads as deliberate
	// pixel art instead of a thin procedural draft.
	vec2 energy_pixel_size = TEXTURE_PIXEL_SIZE
			* max(energy_pixel_size_px, 1.0);
	vec2 circuit_uv = (
			floor(UV / energy_pixel_size) + vec2(0.5)
	) * energy_pixel_size;

	float path_a_mask = 0.0;
	float path_a_progress = 0.0;
	float segment = vertical_segment(
			circuit_uv, 0.31, 0.70, 0.93,
			circuit_width_px, energy_pixel_size);
	if (segment > path_a_mask) {
		path_a_mask = segment;
		path_a_progress = (0.93 - circuit_uv.y) / 0.23 * 0.20;
	}
	segment = horizontal_segment(
			circuit_uv, 0.70, 0.31, 0.49,
			circuit_width_px, energy_pixel_size);
	if (segment > path_a_mask) {
		path_a_mask = segment;
		path_a_progress = 0.20
				+ (circuit_uv.x - 0.31) / 0.18 * 0.16;
	}
	segment = vertical_segment(
			circuit_uv, 0.49, 0.46, 0.70,
			circuit_width_px, energy_pixel_size);
	if (segment > path_a_mask) {
		path_a_mask = segment;
		path_a_progress = 0.36
				+ (0.70 - circuit_uv.y) / 0.24 * 0.22;
	}
	segment = horizontal_segment(
			circuit_uv, 0.46, 0.38, 0.49,
			circuit_width_px, energy_pixel_size);
	if (segment > path_a_mask) {
		path_a_mask = segment;
		path_a_progress = 0.58
				+ (0.49 - circuit_uv.x) / 0.11 * 0.10;
	}
	segment = vertical_segment(
			circuit_uv, 0.38, 0.17, 0.46,
			circuit_width_px, energy_pixel_size);
	if (segment > path_a_mask) {
		path_a_mask = segment;
		path_a_progress = 0.68
				+ (0.46 - circuit_uv.y) / 0.29 * 0.32;
	}

	float path_b_mask = 0.0;
	float path_b_progress = 0.0;
	segment = vertical_segment(
			circuit_uv, 0.69, 0.76, 0.93,
			circuit_width_px, energy_pixel_size);
	if (segment > path_b_mask) {
		path_b_mask = segment;
		path_b_progress = (0.93 - circuit_uv.y) / 0.17 * 0.16;
	}
	segment = horizontal_segment(
			circuit_uv, 0.76, 0.55, 0.69,
			circuit_width_px, energy_pixel_size);
	if (segment > path_b_mask) {
		path_b_mask = segment;
		path_b_progress = 0.16
				+ (0.69 - circuit_uv.x) / 0.14 * 0.12;
	}
	segment = vertical_segment(
			circuit_uv, 0.55, 0.55, 0.76,
			circuit_width_px, energy_pixel_size);
	if (segment > path_b_mask) {
		path_b_mask = segment;
		path_b_progress = 0.28
				+ (0.76 - circuit_uv.y) / 0.21 * 0.20;
	}
	segment = horizontal_segment(
			circuit_uv, 0.55, 0.55, 0.72,
			circuit_width_px, energy_pixel_size);
	if (segment > path_b_mask) {
		path_b_mask = segment;
		path_b_progress = 0.48
				+ (circuit_uv.x - 0.55) / 0.17 * 0.16;
	}
	segment = vertical_segment(
			circuit_uv, 0.72, 0.34, 0.55,
			circuit_width_px, energy_pixel_size);
	if (segment > path_b_mask) {
		path_b_mask = segment;
		path_b_progress = 0.64
				+ (0.55 - circuit_uv.y) / 0.21 * 0.20;
	}
	segment = horizontal_segment(
			circuit_uv, 0.34, 0.61, 0.72,
			circuit_width_px, energy_pixel_size);
	if (segment > path_b_mask) {
		path_b_mask = segment;
		path_b_progress = 0.84
				+ (0.72 - circuit_uv.x) / 0.11 * 0.08;
	}
	segment = vertical_segment(
			circuit_uv, 0.61, 0.16, 0.34,
			circuit_width_px, energy_pixel_size);
	if (segment > path_b_mask) {
		path_b_mask = segment;
		path_b_progress = 0.92
				+ (0.34 - circuit_uv.y) / 0.18 * 0.08;
	}

	// Two monotonic clocks use small low-frequency phase drift instead of a
	// fixed saw-tooth rate. The head still climbs upward, but never repeats with
	// an obviously mechanical cadence across the four stones.
	float clock_a = TIME * pulse_speed;
	float clock_b = TIME * pulse_speed * mix(
			0.78,
			1.09,
			hash11(pulse_phase * 7.7));
	float drift_a = sin(clock_a * TAU * 0.37 + pulse_phase) * 0.032
			+ sin(clock_a * TAU * 0.13 + pulse_phase * 1.61) * 0.018;
	float drift_b = sin(clock_b * TAU * 0.29 + pulse_phase * 0.73) * 0.038
			+ sin(clock_b * TAU * 0.17 + pulse_phase * 1.27) * 0.015;
	float head_a = fract(clock_a + drift_a + pulse_phase / TAU);
	float head_b = fract(clock_b + drift_b + pulse_phase / TAU + 0.37);
	// The old saw-tooth trail jumped from dark to fully lit as its head crossed
	// a circuit pixel. Fade in behind the head and fade out at the tail instead.
	// Spatial blocks stay crisp, but every block changes brightness continuously.
	float travel_a = fract(head_a - path_a_progress);
	float travel_b = fract(head_b - path_b_progress);
	float front_fade_a = smoothstep(0.0, motion_feather, travel_a);
	float front_fade_b = smoothstep(0.0, motion_feather, travel_b);
	float flash = clamp(interaction_flash, 0.0, 1.0);
	float achievement_extension = smoothstep(
			0.0,
			1.0,
			clamp(achievement_sync, 0.0, 1.0));
	// Growing travel distance keeps the reveal anchored to head_a/head_b. It
	// does not light a second mask or restart either path's TIME-based motion.
	float active_tail_a = mix(circuit_tail, 0.94, achievement_extension);
	float active_tail_b = mix(
			circuit_tail * 0.78,
			0.90,
			achievement_extension);
	float trail_a = front_fade_a * (
			1.0 - smoothstep(
					max(active_tail_a - motion_feather, motion_feather),
					active_tail_a,
					travel_a));
	float trail_b = front_fade_b * (
			1.0 - smoothstep(
					max(
							active_tail_b - motion_feather,
							motion_feather),
					active_tail_b,
					travel_b));
	float circuit_mask = max(path_a_mask, path_b_mask) * source.a;
	float head_core_a = 1.0 - smoothstep(
			0.0, max(motion_feather * 0.72, 0.012), travel_a);
	float head_core_b = 1.0 - smoothstep(
			0.0, max(motion_feather * 0.68, 0.012), travel_b);
	float energy_a = path_a_mask * max(trail_a * 0.72, head_core_a);
	float energy_b = path_b_mask * max(trail_b * 0.66, head_core_b);
	float circuit_energy = max(energy_a, energy_b) * source.a;
	float irregular_charge = 0.78
			+ sin(clock_a * TAU * 0.41 + pulse_phase) * 0.12
			+ sin(clock_b * TAU * 0.23 + pulse_phase * 1.7) * 0.07;
	circuit_energy *= irregular_charge;

	// Keep the channel one source pixel inside the authored silhouette. This
	// prevents the procedural route from reading as a loose sketch laid over
	// chipped edges or transparent breaks in the stone.
	float neighbour_alpha = source.a;
	neighbour_alpha = min(
			neighbour_alpha,
			texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbour_alpha = min(
			neighbour_alpha,
			texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbour_alpha = min(
			neighbour_alpha,
			texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
	neighbour_alpha = min(
			neighbour_alpha,
			texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
	float interior_gate = mix(
			0.68,
			1.0,
			smoothstep(0.28, 0.92, neighbour_alpha));

	// The dormant route is a shallow dark groove. Energy inherits the source
	// stone value and a tiny per-pixel variation, so it feels trapped inside
	// weathered material instead of glowing with a flat vector-line finish.
	float pixel_variation = mix(
			0.86,
			1.0,
			hash11(
					floor(circuit_uv.x / TEXTURE_PIXEL_SIZE.x)
					+ floor(circuit_uv.y / TEXTURE_PIXEL_SIZE.y) * 17.0));
	float surface_response = mix(0.64, 1.0, value) * pixel_variation;
	float carved_track = circuit_mask * interior_gate;
	float embedded_energy = circuit_energy * interior_gate * surface_response;
	vec3 groove_color = mix(shadow_color.rgb, mid_color.rgb, 0.18);
	color = mix(
			color,
			groove_color,
			carved_track * (0.18 + base_charge * 0.42));

	// The teal forest absorbs gray light, so the moving route uses a clearer
	// moon-blue value contrast while remaining one restrained color family.
	// Click and achievement feedback multiply only pixels already owned by
	// embedded_energy, so neither event can reveal the full carved route.
	vec3 embedded_color = mix(rune_color.rgb, rune_core_color.rgb, 0.08);
	float moving_flash = embedded_energy * flash;
	float achievement_boost = clamp(
			achievement_sync * 0.52 + achievement_glow * 0.72,
			0.0,
			1.0);
	float achievement_energy = embedded_energy * achievement_boost;
	vec3 flash_color = mix(
			embedded_color,
			rune_core_color.rgb,
			clamp(flash * 0.48 + achievement_boost * 0.24, 0.0, 0.68));
	float light_amount = glow_strength * embedded_energy * 1.86
			+ moving_flash * interaction_flash_gain
			+ achievement_energy * 0.78;
	color = mix(
			color,
			flash_color,
			clamp(light_amount, 0.0, 0.96));

	// A one-pixel pale core stays on the travelling head, not the full route.
	// It gives the slow energy enough focus against the dark green background.
	float head_core_energy = max(
			path_a_mask * head_core_a,
			path_b_mask * head_core_b) * source.a
			* interior_gate * surface_response;
	float achievement_head_energy = head_core_energy * achievement_boost;
	float core_light = head_core_energy * (0.54 + glow_strength * 0.46)
			* mix(1.0, 1.85, flash)
			+ achievement_head_energy * 0.46;
	color = mix(
			color,
			rune_core_color.rgb,
			clamp(core_light, 0.0, 0.9));

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source.a)
			* node_modulate;
}
