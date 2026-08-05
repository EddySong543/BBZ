shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform vec4 ray_color : source_color = vec4(1.0, 0.65, 0.12, 0.82);
uniform vec4 ring_color : source_color = vec4(1.0, 0.78, 0.28, 0.46);
uniform float intensity : hint_range(0.0, 2.0, 0.01) = 0.88;
uniform float core_radius : hint_range(0.08, 0.28, 0.005) = 0.18;
uniform float ray_width : hint_range(0.01, 0.3, 0.005) = 0.055;
uniform float horizontal_length : hint_range(0.2, 1.0, 0.01) = 0.94;
uniform float vertical_length : hint_range(0.2, 1.0, 0.01) = 0.72;
uniform float ray_curve : hint_range(0.0, 0.15, 0.005) = 0.045;
uniform float ray_pulse_strength : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform float ray_pulse_width : hint_range(0.04, 0.3, 0.01) = 0.14;
uniform float ring_strength : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float ring_birth_duration : hint_range(0.06, 0.3, 0.01) = 0.16;
uniform float ring_fade_start : hint_range(0.3, 0.8, 0.01) = 0.52;
uniform float grid_size : hint_range(8.0, 96.0, 1.0) = 48.0;
uniform float pulse_amount : hint_range(0.0, 0.3, 0.01) = 0.055;
uniform float pulse_phase : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float intro_pulse_enabled : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float intro_pulse_progress : hint_range(0.0, 1.0, 0.001) = 0.0;

void fragment() {
	vec2 pixel_uv = floor(UV * grid_size + vec2(0.5)) / grid_size;
	vec2 point = (pixel_uv - vec2(0.5)) * 2.0;
	float abs_x = abs(point.x);
	float abs_y = abs(point.y);
	float outward_phase = mix(
			fract(pulse_phase * 2.0),
			clamp(intro_pulse_progress, 0.0, 1.0),
			clamp(intro_pulse_enabled, 0.0, 1.0));
	float pulse_envelope = sin(outward_phase * 3.14159265);
	float intro_ray_extent = mix(
			1.0,
			smoothstep(0.06, 0.56, outward_phase),
			clamp(intro_pulse_enabled, 0.0, 1.0));

	float horizontal_progress = clamp(
			abs_x / horizontal_length,
			0.0,
			1.0);
	float vertical_progress = clamp(
			abs_y / vertical_length,
			0.0,
			1.0);
	float horizontal_center = (
			sign(point.x)
			* ray_curve
			* sin(horizontal_progress * 3.14159265));
	float vertical_center = (
			-sign(point.y)
			* ray_curve
			* sin(vertical_progress * 3.14159265));

	float horizontal_swell = mix(
			0.28,
			1.0,
			sin(horizontal_progress * 3.14159265));
	float vertical_swell = mix(
			0.28,
			1.0,
			sin(vertical_progress * 3.14159265));
	float horizontal_profile = (
			horizontal_swell
			* pow(max(0.0, 1.0 - horizontal_progress), 0.7));
	float vertical_profile = (
			vertical_swell
			* pow(max(0.0, 1.0 - vertical_progress), 0.7));

	float horizontal_width = ray_width * horizontal_profile;
	float vertical_width = ray_width * vertical_profile;
	float horizontal_ray = (
			(1.0 - smoothstep(
				horizontal_width,
				horizontal_width + 0.025,
				abs(point.y - horizontal_center)))
			* step(
					abs_x,
					horizontal_length * intro_ray_extent));
	float vertical_ray = (
			(1.0 - smoothstep(
				vertical_width,
				vertical_width + 0.025,
				abs(point.x - vertical_center)))
			* step(
					abs_y,
					vertical_length * intro_ray_extent));
	float horizontal_pulse = (
			1.0
			- smoothstep(
				0.0,
				ray_pulse_width,
				abs(horizontal_progress - outward_phase)));
	float vertical_pulse = (
			1.0
			- smoothstep(
				0.0,
				ray_pulse_width,
				abs(vertical_progress - outward_phase)));
	float horizontal_energy = horizontal_ray * (
			0.72
			+ horizontal_pulse * pulse_envelope * ray_pulse_strength);
	float vertical_energy = vertical_ray * (
			0.72
			+ vertical_pulse * pulse_envelope * ray_pulse_strength);

	float radial_distance = length(point);
	float core = 1.0 - smoothstep(
			core_radius * 0.62,
			core_radius,
			radial_distance);
	float static_ring_radius = 0.25;
	float inner_flare_outer = min(
			core_radius + 0.05,
			static_ring_radius - 0.02);
	float inner_flare = 1.0 - smoothstep(
			core_radius,
			inner_flare_outer,
			radial_distance);
	float static_ring = 1.0 - smoothstep(
			0.01,
			0.028,
			abs(radial_distance - static_ring_radius));
	float ring_birth = smoothstep(
			0.02,
			ring_birth_duration,
			outward_phase);
	float ring_fade = (
			1.0
			- smoothstep(ring_fade_start, 1.0, outward_phase));
	float ring_visibility = ring_birth * ring_fade;
	float ring_travel = smoothstep(0.04, 0.92, outward_phase);
	float release_ring_radius = mix(
			static_ring_radius + 0.008,
			0.54,
			ring_travel);
	float release_ring_width = mix(0.055, 0.014, ring_travel);
	float release_ring = (
			1.0
			- smoothstep(
				release_ring_width,
				release_ring_width + 0.025,
				abs(radial_distance - release_ring_radius)));
	release_ring *= ring_visibility;
	float rays = max(horizontal_energy, vertical_energy);
	float core_release_progress = min(outward_phase / 0.32, 1.0);
	float core_release = sin(core_release_progress * 3.14159265);
	float rings = max(
			static_ring * (0.32 + core_release * 0.12),
			release_ring * ring_strength);
	float pulse = 1.0 + core_release * pulse_amount;
	float star_alpha = clamp(
			max(
				max(max(core, inner_flare * 0.42), rays * 0.86),
				rings)
			* intensity
			* pulse,
			0.0,
			1.0);
	vec3 star_color = mix(
			ray_color.rgb,
			core_color.rgb,
			max(core, inner_flare * 0.5));
	star_color = mix(
			star_color,
			ring_color.rgb,
			clamp(rings * ring_color.a, 0.0, 1.0));
	COLOR = vec4(star_color * star_alpha, star_alpha);
}
