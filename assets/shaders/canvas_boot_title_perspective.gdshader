shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float perspective_strength : hint_range(0.0, 0.35, 0.01) = 0.26;
uniform float edge_padding : hint_range(0.0, 0.45, 0.01) = 0.04;

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

uniform float flow_phase : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float flow_delay : hint_range(0.0, 0.25, 0.001) = 0.0;
uniform float flow_duration : hint_range(0.001, 0.5, 0.001) = 0.107143;
uniform float release_duration : hint_range(0.001, 0.25, 0.001) = 0.052381;
uniform float flow_start_uv_x : hint_range(0.0, 1.0, 0.001) = 0.18;
uniform float flow_end_uv_x : hint_range(0.0, 1.0, 0.001) = 0.89;
uniform float fragment_origin_uv_y : hint_range(0.0, 1.0, 0.001) = 0.31;
uniform float head_width_texels : hint_range(1.0, 12.0, 1.0) = 6.0;
uniform float tail_length_texels : hint_range(4.0, 48.0, 1.0) = 28.0;
uniform float structure_tint_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float fragment_strength : hint_range(0.0, 1.0, 0.01) = 0.85;

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


float moving_flow_intensity(
		float source_pixel_x,
		float head_pixel_x,
		float entry_ramp
) {
	float distance_to_head = abs(source_pixel_x - head_pixel_x);
	float head = 1.0 - smoothstep(
			0.0,
			max(head_width_texels, 1.0),
			distance_to_head);
	float trail_distance = head_pixel_x - source_pixel_x;
	float trail = (
			step(0.0, trail_distance)
			* (
				1.0
				- smoothstep(
						0.0,
						max(tail_length_texels, 1.0),
						trail_distance)
			)
			* 0.68);
	return max(head, trail) * entry_ramp;
}


float square_fragment(
		vec2 source_pixel,
		vec2 center,
		float half_size
) {
	vec2 delta = abs(source_pixel - center);
	return 1.0 - step(
			half_size,
			max(delta.x, delta.y));
}


void fragment() {
	float padding = clamp(edge_padding, 0.0, 0.45);
	float usable_span = max(1.0 - padding * 2.0, 0.001);
	vec2 trapezoid_uv = (UV - vec2(padding)) / usable_span;

	float strength = clamp(perspective_strength, 0.0, 0.35);
	float projected_x = clamp(trapezoid_uv.x, 0.0, 1.0);
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

		if (flow_active) {
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
			float entry_ramp = smoothstep(0.0, 0.12, flow_progress);
			flow_intensity = moving_flow_intensity(
					source_pixel.x,
					head_pixel_x,
					entry_ramp);
		} else if (release_active) {
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
			flow_intensity = (
					1.0
					- smoothstep(
							0.0,
							max(head_width_texels, 1.0),
							abs(source_pixel.x - endpoint_pixel_x))
				) * endpoint_hold;
		}

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

		float fragment_intensity = 0.0;
		if (release_active) {
			vec2 fragment_origin = vec2(
					flow_end_uv_x / TEXTURE_PIXEL_SIZE.x + 2.0,
					fragment_origin_uv_y / TEXTURE_PIXEL_SIZE.y);
			float release_ramp = (
					smoothstep(0.0, 0.10, release_progress)
					* (
						1.0
						- smoothstep(0.62, 1.0, release_progress)
					));
			vec2 fragment_one = fragment_origin + vec2(
					3.0 + 15.0 * release_progress,
					-1.0 - 4.0 * release_progress);
			vec2 fragment_two = fragment_origin + vec2(
					2.0 + 11.0 * release_progress,
					3.0 + 2.0 * release_progress);
			vec2 fragment_three = fragment_origin + vec2(
					5.0 + 8.0 * release_progress,
					-5.0 + release_progress);
			float fragment_mask = max(
					square_fragment(
							source_pixel,
							fragment_one,
							1.15),
					max(
						square_fragment(
								source_pixel,
								fragment_two,
								0.85),
						square_fragment(
								source_pixel,
								fragment_three,
								0.75)));
			fragment_intensity = (
					fragment_mask
					* release_ramp
					* clamp(fragment_strength, 0.0, 1.0));
		}

		if (fragment_intensity > 0.001) {
			if (mapped_color.a <= 0.001) {
				mapped_color = vec4(
						energy_peak_color.rgb,
						fragment_intensity);
			} else {
				mapped_color.rgb = mix(
						mapped_color.rgb,
						energy_peak_color.rgb,
						fragment_intensity);
			}
		}

		COLOR = mapped_color * vertex_color;
	}
}
