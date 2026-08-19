shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float perspective_strength : hint_range(0.0, 0.35, 0.01) = 0.26;
uniform float edge_padding : hint_range(0.0, 0.45, 0.01) = 0.04;
uniform float group_x_min : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float group_x_max : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float pointer_yaw : hint_range(-1.0, 1.0, 0.001) = 0.0;
uniform float pointer_pitch : hint_range(-1.0, 1.0, 0.001) = 0.0;
uniform float pointer_yaw_strength : hint_range(0.0, 0.2, 0.001) = 0.105;
uniform float pointer_pitch_strength : hint_range(0.0, 0.1, 0.001) = 0.044;

uniform vec4 source_structure_color : source_color = vec4(
		0.058824, 0.105882, 0.149020, 1.0);
uniform vec4 source_face_color : source_color = vec4(
		0.960784, 0.909804, 0.819608, 1.0);
uniform vec4 source_energy_color : source_color = vec4(
		0.866667, 0.337255, 0.223529, 1.0);

uniform vec4 structure_color : source_color = vec4(
		0.058824, 0.105882, 0.149020, 1.0);
uniform vec4 face_color : source_color = vec4(
		0.960784, 0.909804, 0.819608, 1.0);
uniform vec4 energy_color : source_color = vec4(
		0.866667, 0.337255, 0.223529, 1.0);
uniform vec4 energy_peak_color : source_color = vec4(
		0.960784, 0.909804, 0.819608, 1.0);

uniform bool flow_enabled = true;
uniform float flow_phase : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float flow_delay : hint_range(0.0, 0.25, 0.001) = 0.0;
uniform float flow_duration : hint_range(0.001, 0.5, 0.001) = 0.321429;
uniform float release_duration : hint_range(0.001, 0.25, 0.001) = 0.166667;
uniform float flow_start_uv_x : hint_range(0.0, 1.0, 0.001) = 0.18;
uniform float flow_end_uv_x : hint_range(0.0, 1.0, 0.001) = 0.89;
uniform float head_width_texels : hint_range(1.0, 12.0, 1.0) = 6.0;
uniform float tail_length_texels : hint_range(4.0, 48.0, 1.0) = 28.0;
uniform float flow_pixel_step_texels : hint_range(1.0, 8.0, 1.0) = 4.0;
uniform float flow_value_steps : hint_range(2.0, 8.0, 1.0) = 3.0;
uniform float structure_tint_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform vec4 outline_color : source_color = vec4(
		0.058824, 0.105882, 0.149020, 0.88);
uniform float outline_width_texels : hint_range(0.0, 2.0, 0.25) = 1.0;
uniform float outline_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D intro_activation_map : filter_nearest, repeat_disable;
uniform float intro_reveal_progress : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float intro_reveal_feather : hint_range(0.001, 0.05, 0.001) = 0.012;
uniform float intro_progress_delay : hint_range(0.0, 0.25, 0.001) = 0.0;
uniform bool intro_shadow = false;
uniform float intro_shadow_lag : hint_range(0.0, 0.20, 0.001) = 0.055;
uniform float intro_crack_peak_width : hint_range(0.01, 0.30, 0.001) = 0.11;

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


float structure_mask(vec4 sampled_color) {
	if (sampled_color.a <= 0.001) {
		return 0.0;
	}

	float structure_distance = distance(
			sampled_color.rgb,
			source_structure_color.rgb);
	float face_distance = distance(
			sampled_color.rgb,
			source_face_color.rgb);
	float energy_distance = distance(
			sampled_color.rgb,
			source_energy_color.rgb);
	return float(
		structure_distance <= face_distance
		&& structure_distance <= energy_distance);
}


float energy_mask(vec4 sampled_color) {
	if (sampled_color.a <= 0.001) {
		return 0.0;
	}

	float structure_distance = distance(
			sampled_color.rgb,
			source_structure_color.rgb);
	float face_distance = distance(
			sampled_color.rgb,
			source_face_color.rgb);
	float energy_distance = distance(
			sampled_color.rgb,
			source_energy_color.rgb);
	return float(
		energy_distance <= structure_distance
		&& energy_distance <= face_distance);
}


vec4 remap_title_color(vec4 sampled_color) {
	if (sampled_color.a <= 0.001) {
		return vec4(0.0);
	}

	float structure_distance = distance(
			sampled_color.rgb,
			source_structure_color.rgb);
	float face_distance = distance(
			sampled_color.rgb,
			source_face_color.rgb);
	float energy_distance = distance(
			sampled_color.rgb,
			source_energy_color.rgb);
	vec4 mapped_color = structure_color;

	if (
			face_distance <= structure_distance
			&& face_distance <= energy_distance
	) {
		mapped_color = face_color;
	} else if (
			energy_distance <= structure_distance
			&& energy_distance <= face_distance
	) {
		mapped_color = energy_color;
	}

	mapped_color.a *= sampled_color.a;
	return mapped_color;
}


float flow_cell_intensity(
		float source_cell,
		float head_cell,
		float flow_direction
) {
	float cell_delta = head_cell - source_cell;
	float pixel_step = max(flow_pixel_step_texels, 1.0);
	float head_radius_cells = max(
			floor(
				head_width_texels
				/ pixel_step
				* 0.5),
			0.0);
	float tail_cells = max(
			floor(tail_length_texels / pixel_step + 0.5),
			1.0);
	float distance_to_head = abs(cell_delta);
	float head = 1.0 - step(
			head_radius_cells + 0.01,
			distance_to_head);
	float trail_distance = cell_delta * flow_direction;
	float trail_active = (
			step(0.0, trail_distance)
			* (1.0 - step(tail_cells + 0.01, trail_distance)));
	float trail_progress = clamp(
			trail_distance / tail_cells,
			0.0,
			1.0);
	float value_steps = max(flow_value_steps, 2.0);
	float stepped_trail = (
			floor((1.0 - trail_progress) * value_steps)
			/ value_steps);
	float pattern_slot = mod(floor(trail_distance), 3.0);
	float block_pattern = mix(
			1.0,
			0.50,
			step(1.0, pattern_slot));
	block_pattern = mix(
			block_pattern,
			0.10,
			step(2.0, pattern_slot));
	return max(
			head,
			stepped_trail
				* block_pattern
				* 0.72
				* trail_active);
}


float moving_flow_intensity(
		float source_pixel_x,
		float head_pixel_x,
		float flow_direction,
		float entry_ramp
) {
	float pixel_step = max(flow_pixel_step_texels, 1.0);
	float source_cell = floor(source_pixel_x / pixel_step);
	float continuous_head_cell = head_pixel_x / pixel_step;
	float lower_head_cell = floor(continuous_head_cell);
	float upper_head_cell = lower_head_cell + 1.0;
	float cell_blend = fract(continuous_head_cell);
	float lower_intensity = flow_cell_intensity(
			source_cell,
			lower_head_cell,
			flow_direction);
	float upper_intensity = flow_cell_intensity(
			source_cell,
			upper_head_cell,
			flow_direction);
	return mix(
			lower_intensity,
			upper_intensity,
			cell_blend) * clamp(entry_ramp, 0.0, 1.0);
}


void fragment() {
	float padding = clamp(edge_padding, 0.0, 0.45);
	float usable_span = max(1.0 - padding * 2.0, 0.001);
	vec2 trapezoid_uv = (UV - vec2(padding)) / usable_span;

	float strength = clamp(perspective_strength, 0.0, 0.35);
	float projected_x = clamp(
			mix(group_x_min, group_x_max, trapezoid_uv.x),
			0.0,
			1.0);
	float group_pointer_x = projected_x - 0.5;
	float group_pointer_y = trapezoid_uv.y - 0.5;
	float yaw_scale = (
			1.0
			+ group_pointer_x
				* pointer_yaw
				* pointer_yaw_strength);
	float pitch_scale = (
			1.0
			+ group_pointer_y
				* pointer_pitch
				* pointer_pitch_strength);
	float pointer_scale = max(yaw_scale * pitch_scale, 0.82);
	trapezoid_uv = vec2(0.5) + (
			trapezoid_uv - vec2(0.5)) / pointer_scale;
	projected_x = clamp(
			mix(group_x_min, group_x_max, trapezoid_uv.x),
			0.0,
			1.0);
	float vertical_scale = 1.0 - strength * projected_x;
	float source_y = 0.5 + (trapezoid_uv.y - 0.5) / vertical_scale;

	bool inside_bounds = (
		trapezoid_uv.x >= 0.0
		&& trapezoid_uv.x <= 1.0
		&& source_y >= 0.0
		&& source_y <= 1.0);

	if (!inside_bounds) {
		COLOR = vec4(0.0);
	} else {
		vec2 source_uv = vec2(trapezoid_uv.x, source_y);
		vec4 sampled_color = texture(TEXTURE, source_uv);
		vec4 mapped_color = remap_title_color(sampled_color);
		vec2 source_pixel = source_uv / TEXTURE_PIXEL_SIZE;

		float local_phase = fract(flow_phase - flow_delay);
		bool flow_active = local_phase <= flow_duration;
		bool release_active = (
				local_phase > flow_duration
				&& local_phase <= flow_duration + release_duration);
		float flow_intensity = 0.0;
		float release_progress = 0.0;

		if (flow_enabled && flow_active) {
			float flow_progress = clamp(
					local_phase / max(flow_duration, 0.001),
					0.0,
					1.0);
			float eased_progress = (
					flow_progress
					* flow_progress
					* (3.0 - 2.0 * flow_progress));
			float head_uv_x = mix(
					flow_start_uv_x,
					flow_end_uv_x,
					eased_progress);
			float head_pixel_x = head_uv_x / TEXTURE_PIXEL_SIZE.x;
			float flow_direction = sign(
					flow_end_uv_x - flow_start_uv_x);
			float entry_ramp = clamp(flow_progress / 0.12, 0.0, 1.0);
			flow_intensity = moving_flow_intensity(
					source_pixel.x,
					head_pixel_x,
					flow_direction,
					entry_ramp);
		} else if (flow_enabled && release_active) {
			release_progress = clamp(
					(local_phase - flow_duration)
					/ max(release_duration, 0.001),
					0.0,
					1.0);
			float endpoint_pixel_x = (
					flow_end_uv_x / TEXTURE_PIXEL_SIZE.x);
			float endpoint_hold = (
					1.0
					- smoothstep(0.0, 0.62, release_progress));
			float safe_pixel_step = max(
					flow_pixel_step_texels,
					1.0);
			float source_cell = floor(
					source_pixel.x / safe_pixel_step);
			float endpoint_cell = floor(
					endpoint_pixel_x / safe_pixel_step + 0.5);
			float endpoint_cells = max(
					floor(
						head_width_texels / safe_pixel_step
						+ 0.5),
					1.0);
			float endpoint_block = (
					1.0
					- step(
							endpoint_cells + 0.01,
							abs(source_cell - endpoint_cell)));
			flow_intensity = endpoint_block * endpoint_hold;
		}
		flow_intensity = clamp(flow_intensity, 0.0, 1.0);

		float current_energy = energy_mask(sampled_color);
		if (current_energy > 0.5 && flow_intensity > 0.001) {
			mapped_color = mix(
					energy_color,
					energy_peak_color,
					clamp(flow_intensity, 0.0, 1.0));
			mapped_color.a *= sampled_color.a;
		}

		if (
				structure_mask(sampled_color) > 0.5
				&& flow_intensity > 0.001
		) {
			float adjacent_energy = max(
					energy_mask(texture(
							TEXTURE,
							clamp(
									source_uv
									+ vec2(0.0, -1.0)
									* TEXTURE_PIXEL_SIZE,
									vec2(0.0),
									vec2(1.0)))),
					energy_mask(texture(
							TEXTURE,
							clamp(
									source_uv
									+ vec2(0.0, -2.0)
									* TEXTURE_PIXEL_SIZE,
									vec2(0.0),
									vec2(1.0)))));
			vec3 engraved_shadow = mix(
					structure_color.rgb,
					energy_color.rgb,
					0.38);
			mapped_color.rgb = mix(
					mapped_color.rgb,
					engraved_shadow,
					adjacent_energy
					* flow_intensity
					* clamp(structure_tint_strength, 0.0, 1.0));
		}

		if (
				mapped_color.a <= 0.001
				&& outline_strength > 0.001
		) {
			float neighbor_alpha = 0.0;
			for (int ring = 1; ring <= 2; ring++) {
				float enabled = step(
						float(ring),
						outline_width_texels);
				vec2 texel = (
						TEXTURE_PIXEL_SIZE
						* float(ring));
				float ring_alpha = 0.0;
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv + vec2(
								texel.x, 0.0)).a);
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv - vec2(
								texel.x, 0.0)).a);
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv + vec2(
								0.0, texel.y)).a);
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv - vec2(
								0.0, texel.y)).a);
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv + texel).a);
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv - texel).a);
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv + vec2(
								texel.x, -texel.y)).a);
				ring_alpha = max(
						ring_alpha,
						texture(TEXTURE, source_uv + vec2(
								-texel.x, texel.y)).a);
				neighbor_alpha = max(
						neighbor_alpha,
						ring_alpha * enabled);
			}
			mapped_color = vec4(
					outline_color.rgb,
					neighbor_alpha
					* outline_color.a
					* outline_strength);
		}

		vec2 intro_activation = texture(
				intro_activation_map,
				source_uv).rg;
		float face_activation = intro_activation.r;
		float crack_activation = intro_activation.g;
		float delayed_progress = clamp(
				(intro_reveal_progress - intro_progress_delay)
					/ max(1.0 - intro_progress_delay, 0.001),
				0.0,
				1.0);
		float safe_feather = max(intro_reveal_feather, 0.001);
		float face_threshold = face_activation;
		if (intro_shadow) {
			face_threshold += intro_shadow_lag;
		}
		float face_reveal = smoothstep(
				face_threshold - safe_feather,
				face_threshold + safe_feather,
				delayed_progress);
		float crack_reveal = smoothstep(
				crack_activation - safe_feather,
				crack_activation + safe_feather,
				delayed_progress);
		float source_is_energy = energy_mask(sampled_color);
		float pixel_reveal = mix(
				face_reveal,
				crack_reveal,
				source_is_energy);
		if (intro_shadow) {
			pixel_reveal = face_reveal;
		}
		if (!intro_shadow && source_is_energy > 0.5) {
			float crack_age = max(
					delayed_progress - crack_activation,
					0.0);
			float crack_head = (
					1.0
					- smoothstep(
							0.0,
							intro_crack_peak_width,
							crack_age));
			mapped_color.rgb = mix(
					mapped_color.rgb,
					energy_peak_color.rgb,
					crack_head * crack_reveal * 0.78);
		}
		if (intro_reveal_progress <= 0.001) {
			pixel_reveal = 0.0;
		} else if (intro_reveal_progress >= 0.999) {
			pixel_reveal = 1.0;
		}
		mapped_color.a *= pixel_reveal;
		COLOR = mapped_color * vertex_color;
	}
}
