shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene8 ref48 aurora motion. The accepted 256x144 source remains untouched:
// this material moves every occupied texel as one continuous curtain, with
// broad phase-separated folds instead of local particles or random jitter.

uniform vec2 logical_size = vec2(256.0, 144.0);
uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform float curtain_height_pixels : hint_range(32.0, 144.0, 1.0) = 71.0;
uniform float primary_cycle_sec : hint_range(8.0, 60.0, 0.1) = 26.0;
uniform float secondary_cycle_sec : hint_range(8.0, 60.0, 0.1) = 38.0;
uniform float energy_cycle_sec : hint_range(8.0, 60.0, 0.1) = 28.0;
uniform float sway_x_pixels : hint_range(0.0, 4.0, 0.1) = 1.8;
uniform float sway_y_pixels : hint_range(0.0, 3.0, 0.1) = 1.1;
uniform float motion_floor : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float energy_strength : hint_range(0.0, 0.4, 0.01) = 0.14;
uniform float alpha_variation : hint_range(0.0, 0.20, 0.01) = 0.06;
uniform float body_opacity_top : hint_range(0.4, 1.0, 0.01) = 0.74;
uniform float body_opacity_bottom : hint_range(0.4, 1.0, 0.01) = 0.89;
uniform float halo_strength : hint_range(0.0, 0.4, 0.01) = 0.14;
uniform float halo_radius_pixels : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform float diagnostic_time_sec : hint_range(-1.0, 300.0, 0.1) = -1.0;

varying vec4 vertex_modulate;


void vertex() {
	vertex_modulate = COLOR;
}


vec4 aurora_texel(vec2 logical_pixel) {
	if (logical_pixel.x < 0.0 || logical_pixel.y < 0.0
			|| logical_pixel.x >= logical_size.x
			|| logical_pixel.y >= logical_size.y) {
		return vec4(0.0);
	}
	vec2 snapped_uv = (floor(logical_pixel) + vec2(0.5)) / logical_size;
	return texture(source_texture, snapped_uv);
}


void fragment() {
	float fx_time = diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
	vec2 output_pixel = floor(UV * logical_size);
	float depth = clamp(
			(output_pixel.y + 0.5) / max(curtain_height_pixels, 1.0), 0.0, 1.0);
	float participation = mix(motion_floor, 1.0, depth);
	float phase_x = (output_pixel.x + 0.5) / logical_size.x * TAU;
	float primary_phase = fx_time * TAU / max(primary_cycle_sec, 0.001);
	float secondary_phase = fx_time * TAU / max(secondary_cycle_sec, 0.001);

	// Two differently directed waves prevent all curtains moving in lockstep.
	float broad_sway = sin(
			primary_phase + phase_x * 1.35 + depth * 0.65);
	float folded_sway = sin(
			-secondary_phase + phase_x * 2.85 - depth * 1.70);
	float broad_lift = sin(
			primary_phase * 0.82 - phase_x * 1.10 + depth * 1.35);
	float folded_lift = sin(
			secondary_phase * 1.14 + phase_x * 2.10 + depth * 2.25);
	vec2 displacement_px = vec2(
			sway_x_pixels * participation
					* (broad_sway * 0.68 + folded_sway * 0.32),
			sway_y_pixels * participation
					* (broad_lift * 0.62 + folded_lift * 0.38));

	// Inverse-map and snap to logical texel centers. The displayed sprite keeps
	// hard pixel edges even though the phase itself advances continuously.
	vec2 source_px = output_pixel - displacement_px;
	vec2 source_pixel = floor(source_px + vec2(0.5));
	vec4 texel = aurora_texel(source_pixel);

	// A small logical-pixel halo is derived from the same moving source. It lets
	// the night sky show through and softens the cutout boundary without adding
	// a duplicate sprite, blur texture, or independently moving overlay.
	vec4 neighbor_left = aurora_texel(
			source_pixel + vec2(-halo_radius_pixels, 0.0));
	vec4 neighbor_right = aurora_texel(
			source_pixel + vec2(halo_radius_pixels, 0.0));
	vec4 neighbor_up = aurora_texel(
			source_pixel + vec2(0.0, -halo_radius_pixels));
	vec4 neighbor_down = aurora_texel(
			source_pixel + vec2(0.0, halo_radius_pixels));
	vec4 neighbor_up_left = aurora_texel(
			source_pixel + vec2(-halo_radius_pixels, -halo_radius_pixels));
	vec4 neighbor_up_right = aurora_texel(
			source_pixel + vec2(halo_radius_pixels, -halo_radius_pixels));
	vec4 neighbor_down_left = aurora_texel(
			source_pixel + vec2(-halo_radius_pixels, halo_radius_pixels));
	vec4 neighbor_down_right = aurora_texel(
			source_pixel + vec2(halo_radius_pixels, halo_radius_pixels));
	float neighbor_weight = neighbor_left.a + neighbor_right.a
			+ neighbor_up.a + neighbor_down.a
			+ neighbor_up_left.a + neighbor_up_right.a
			+ neighbor_down_left.a + neighbor_down_right.a;
	vec3 neighbor_light = (
			neighbor_left.rgb * neighbor_left.a
			+ neighbor_right.rgb * neighbor_right.a
			+ neighbor_up.rgb * neighbor_up.a
			+ neighbor_down.rgb * neighbor_down.a
			+ neighbor_up_left.rgb * neighbor_up_left.a
			+ neighbor_up_right.rgb * neighbor_up_right.a
			+ neighbor_down_left.rgb * neighbor_down_left.a
			+ neighbor_down_right.rgb * neighbor_down_right.a)
			/ max(neighbor_weight, 0.001);
	float neighbor_presence = clamp(neighbor_weight / 3.0, 0.0, 1.0);
	float halo_only = max(neighbor_presence - texel.a, 0.0);

	// One long energy clock drives two wide fronts. Color and opacity now change
	// continuously, avoiding the previous fast five-step brightness flicker.
	float energy_phase = fx_time * TAU / max(energy_cycle_sec, 0.001);
	float energy_a = 0.5 + 0.5 * sin(
			energy_phase - phase_x * 1.35 + depth * 0.70);
	float energy_b = 0.5 + 0.5 * sin(
			energy_phase * 0.61 + phase_x * 2.0 - depth);
	float energy = energy_a * 0.68 + energy_b * 0.32;
	float brightness = 1.0 + energy_strength * (energy * 1.20 - 0.40);
	vec3 moving_tint = mix(
			vec3(0.97, 1.03, 1.01),
			vec3(1.03, 0.98, 1.07),
			energy_b * 0.36);
	float depth_opacity = mix(
			body_opacity_top, body_opacity_bottom,
			smoothstep(0.05, 1.0, depth));
	float veil_alpha = mix(1.0 - alpha_variation, 1.0, energy);
	float body_alpha = texel.a * depth_opacity * veil_alpha;
	float halo_alpha = halo_only * halo_strength * mix(0.76, 1.0, energy);
	vec3 body_color = texel.rgb * brightness * moving_tint;
	vec3 halo_color = mix(
			neighbor_light, vec3(0.12, 0.25, 0.39), 0.24)
			* mix(0.78, 1.0, energy);
	float combined_alpha = body_alpha + halo_alpha * (1.0 - body_alpha);
	vec3 combined_premultiplied = body_color * body_alpha
			+ halo_color * halo_alpha * (1.0 - body_alpha);
	vec3 combined_color = combined_premultiplied / max(combined_alpha, 0.001);
	COLOR = vec4(combined_color, combined_alpha) * vertex_modulate;
}
