shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 ambient_tint : source_color = vec4(0.72, 0.86, 0.76, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.83, 1.0);
uniform float base_brightness : hint_range(0.5, 1.5) = 0.92;
uniform float emission_threshold : hint_range(0.0, 1.0) = 0.24;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.62;
uniform float halo_strength : hint_range(0.0, 2.0) = 0.5;
uniform float halo_alpha : hint_range(0.0, 1.0) = 0.34;
uniform float halo_radius : hint_range(0.5, 3.0) = 1.5;
uniform float source_cyan_compression : hint_range(0.0, 1.0) = 0.0;
uniform float source_cyan_value_start : hint_range(0.0, 1.0) = 0.32;
uniform float source_cyan_value_ceiling : hint_range(0.1, 1.0) = 0.5;
uniform vec4 source_cyan_tint : source_color = vec4(0.1, 0.58, 0.46, 1.0);
// Midground assets already contain authored cyan-white plant tips.  Preserve
// those tips as a controlled jade core instead of compressing every cool pixel
// into the body palette.  Foreground materials leave core_preservation at 0.
uniform float core_preservation : hint_range(0.0, 1.0) = 0.0;
uniform float core_start : hint_range(0.3, 0.8) = 0.54;
uniform float core_full : hint_range(0.4, 1.0) = 0.72;
uniform float core_value_floor : hint_range(0.4, 1.0) = 0.68;
uniform float core_value_ceiling : hint_range(0.5, 1.0) = 0.84;
uniform float core_tint_mix : hint_range(0.0, 1.0) = 0.34;
uniform float emission_core_end : hint_range(0.3, 1.0) = 0.86;
uniform float emission_soft_knee : hint_range(0.0, 0.3) = 0.0;
uniform float source_cyan_midtone_lift : hint_range(0.0, 0.15) = 0.0;
uniform float highlight_shoulder_start : hint_range(0.3, 0.9) = 0.58;
uniform float highlight_shoulder_strength : hint_range(0.0, 8.0) = 0.0;
uniform float cool_output_gain : hint_range(0.7, 1.0) = 1.0;
uniform vec4 shadow_palette : source_color = vec4(0.035, 0.19, 0.18, 1.0);
uniform vec4 sunlit_palette : source_color = vec4(0.62, 0.58, 0.36, 1.0);
uniform float palette_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 atmosphere_color : source_color = vec4(0.3, 0.5, 0.47, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.2) = 0.0;
uniform float edge_integration_strength : hint_range(0.0, 0.25) = 0.0;
uniform vec4 contact_color : source_color = vec4(0.035, 0.18, 0.17, 1.0);
uniform vec4 sediment_color : source_color = vec4(0.48, 0.42, 0.26, 1.0);
uniform vec4 reflection_color : source_color = vec4(0.18, 0.62, 0.48, 1.0);
uniform float contact_start : hint_range(0.35, 0.9) = 0.62;
uniform float contact_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sediment_strength : hint_range(0.0, 1.0) = 0.0;
uniform float reflection_strength : hint_range(0.0, 0.5) = 0.0;
uniform float root_merge_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sway_speed : hint_range(0.0, 1.0) = 0.42;
uniform float sway_phase = 0.0;
// Scene2-style rigid branch motion.  RGB channels isolate up to three authored
// terminal leaf groups.  Each group rotates around its real attachment point,
// with source-pixel snapping so the leaves never stretch or ripple.
uniform sampler2D branch_mask : filter_nearest, repeat_disable;
uniform sampler2D branch_source_texture : filter_nearest, repeat_disable;
uniform sampler2D branch_underpaint_texture : filter_nearest, repeat_disable;
uniform float branch_underpaint_enabled : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float branch_motion_enabled : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform int branch_group_count : hint_range(0, 3, 1) = 0;
uniform float branch_motion_fps : hint_range(2.0, 8.0, 1.0) = 5.0;
uniform vec3 branch_cycle_sec = vec3(10.5, 11.5, 9.75);
uniform vec3 branch_angle_deg = vec3(0.85, 0.65, 0.75);
uniform vec3 branch_phase = vec3(0.0, 1.7, 3.4);
uniform vec2 branch_pivot_a = vec2(0.36, 0.45);
uniform vec2 branch_pivot_b = vec2(0.39, 0.44);
uniform vec2 branch_pivot_c = vec2(0.41, 0.46);
uniform float edge_motion_strength : hint_range(0.0, 0.1) = 0.0;
uniform float glow_pulse_strength : hint_range(0.0, 0.25) = 0.0;
uniform float glow_pulse_speed : hint_range(0.0, 1.5) = 0.5;
uniform float glow_pulse_phase = 0.0;
uniform float point_twinkle_strength : hint_range(0.0, 0.35) = 0.0;
uniform float point_twinkle_speed : hint_range(0.4, 2.0) = 1.0;
uniform float point_twinkle_density : hint_range(0.0, 1.0) = 0.25;
uniform float point_twinkle_phase : hint_range(0.0, 6.3) = 0.0;
uniform float cluster_breathe_strength : hint_range(0.0, 0.25) = 0.0;
uniform float cluster_breathe_speed : hint_range(0.1, 0.8) = 0.36;
uniform float cluster_breathe_phase : hint_range(0.0, 6.3) = 0.0;

void vertex() {
}


vec2 inverse_rotate_pixel_uv(
		vec2 destination_uv,
		vec2 pivot_uv,
		float angle,
		vec2 source_size) {
	vec2 delta_px = (destination_uv - pivot_uv) * source_size;
	float cosine = cos(-angle);
	float sine = sin(-angle);
	vec2 source_px = vec2(
			delta_px.x * cosine - delta_px.y * sine,
			delta_px.x * sine + delta_px.y * cosine);
	source_px = floor(source_px + pivot_uv * source_size + 0.5);
	return source_px / source_size;
}


vec4 alpha_over(vec4 under, vec4 over) {
	float output_alpha = over.a + under.a * (1.0 - over.a);
	vec3 output_rgb = over.rgb + under.rgb * (1.0 - over.a);
	return vec4(output_rgb, output_alpha);
}


vec4 branch_group_sample(
		vec2 destination_uv,
		vec2 pivot_uv,
		float angle,
		int channel_index,
		vec2 source_size) {
	vec2 source_uv = inverse_rotate_pixel_uv(
			destination_uv, pivot_uv, angle, source_size);
	float inside = step(0.0, source_uv.x) * step(source_uv.x, 1.0)
			* step(0.0, source_uv.y) * step(source_uv.y, 1.0);
	source_uv = clamp(source_uv, vec2(0.0), vec2(1.0));
	vec4 mask = texture(branch_mask, source_uv);
	float selected = mask.r;
	if (channel_index == 1) {
		selected = mask.g;
	} else if (channel_index == 2) {
		selected = mask.b;
	}
	vec4 color = texture(branch_source_texture, source_uv);
	color.a *= selected * mask.a * inside;
	color.rgb *= color.a;
	return color;
}


vec4 sample_branch_texture(vec2 destination_uv) {
	vec4 original = texture(branch_source_texture, destination_uv);
	float stepped_time = floor(TIME * branch_motion_fps) / branch_motion_fps;
	vec3 safe_cycles = max(branch_cycle_sec, vec3(0.001));
	vec3 angles = sin(stepped_time * TAU / safe_cycles + branch_phase)
			* radians(branch_angle_deg);
	vec4 local_mask = texture(branch_mask, destination_uv);
	float moving_here = local_mask.r;
	if (branch_group_count >= 2) {
		moving_here = max(moving_here, local_mask.g);
	}
	if (branch_group_count >= 3) {
		moving_here = max(moving_here, local_mask.b);
	}
	vec4 base = original;
	base.a *= 1.0 - moving_here * local_mask.a;
	base.rgb *= base.a;
	vec4 underpaint = vec4(0.0);
	if (branch_underpaint_enabled > 0.5) {
		underpaint = texture(branch_underpaint_texture, destination_uv);
		underpaint.rgb *= underpaint.a;
	}
	vec2 source_size = vec2(textureSize(branch_source_texture, 0));
	vec4 result = alpha_over(underpaint, base);
	result = alpha_over(result, branch_group_sample(
			destination_uv, branch_pivot_a, angles.x, 0, source_size));
	if (branch_group_count >= 2) {
		result = alpha_over(result, branch_group_sample(
				destination_uv, branch_pivot_b, angles.y, 1, source_size));
	}
	if (branch_group_count >= 3) {
		result = alpha_over(result, branch_group_sample(
				destination_uv, branch_pivot_c, angles.z, 2, source_size));
	}
	if (result.a > 0.0) {
		result.rgb /= result.a;
	}
	return result;
}

float cool_source_presence(vec3 color) {
	float cool_value = max(color.g, color.b);
	float warm_value = max(color.r, min(color.g, color.b) * 0.34);
	return smoothstep(0.08, 0.34, cool_value - warm_value);
}


float stable_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(37.17, 91.73))) * 43758.5453);
}


float biolume_core_mask(vec3 color) {
	float cool_value = max(color.g, color.b);
	float cyan_signal = max(0.0, min(color.g, color.b) - color.r * 0.62);
	float vivid_cyan = smoothstep(0.08, 0.24, cyan_signal);
	float core_range = max(core_full, core_start + 0.02);
	float bright_tip = smoothstep(core_start, core_range, cool_value);
	return vivid_cyan * bright_tip * core_preservation;
}


float body_compression_mask(vec3 color, float preserved_core) {
	float cool_value = max(color.g, color.b);
	float bright_cool = cool_source_presence(color)
			* smoothstep(source_cyan_value_start,
					source_cyan_value_start + 0.12, cool_value);
	return bright_cool * (1.0 - preserved_core);
}


vec3 preserve_biolume_core(vec3 color, vec3 sampled_source, float core) {
	float source_value = max(sampled_source.r,
			max(sampled_source.g, sampled_source.b));
	float preserved_value = clamp(
			max(source_value, core_value_floor),
			0.0,
			core_value_ceiling);
	vec3 source_ramp = sampled_source
			* (preserved_value / max(source_value, 0.001));
	float tint_peak = max(glow_color.r, max(glow_color.g, glow_color.b));
	vec3 jade_ramp = glow_color.rgb
			* (preserved_value / max(tint_peak, 0.001));
	vec3 tinted_core = mix(source_ramp, jade_ramp, core_tint_mix);
	return mix(color, tinted_core, core);
}


vec3 grade_embedded_cyan(vec3 color) {
	float cool_value = max(color.g, color.b);
	float preserved_core = biolume_core_mask(color);
	float compression_range = max(0.08,
			source_cyan_value_ceiling - source_cyan_value_start);
	float bright_cool = body_compression_mask(color, preserved_core);
	float excess = max(0.0, cool_value - source_cyan_value_start);
	float soft_ceiling = source_cyan_value_start + compression_range
			* (1.0 - exp(-excess / compression_range));
	float compressed_value = mix(cool_value, soft_ceiling,
			bright_cool * source_cyan_compression);
	float value_scale = compressed_value / max(cool_value, 0.001);
	vec3 compressed = color * value_scale;
	float tint_peak = max(source_cyan_tint.r,
			max(source_cyan_tint.g, source_cyan_tint.b));
	vec3 teal_target = source_cyan_tint.rgb
			* (compressed_value / max(tint_peak, 0.001));
	compressed = mix(compressed, teal_target, 0.18);
	float midtone_band = smoothstep(0.10, 0.26, cool_value)
			* (1.0 - smoothstep(0.56, 0.78, cool_value));
	compressed += source_cyan_tint.rgb / max(tint_peak, 0.001)
			* source_cyan_midtone_lift * midtone_band
			* cool_source_presence(color);
	vec3 compressed_body = mix(color, compressed, bright_cool);
	return preserve_biolume_core(
			compressed_body, color, preserved_core);
}

float emission_core(vec4 sample_color) {
	float cool_value = max(sample_color.g, sample_color.b);
	float knee = max(0.01, emission_soft_knee);
	float preserved_core = biolume_core_mask(sample_color.rgb);
	float actual_highlight = smoothstep(
			emission_threshold - knee, emission_threshold + knee, cool_value);
	float sparse_highlight = actual_highlight
			* cool_source_presence(sample_color.rgb);
	float luma = dot(sample_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	float cyan_signal = max(0.0,
			min(sample_color.g, sample_color.b) - sample_color.r * 0.62);
	float legacy_highlight = smoothstep(emission_threshold, 0.72,
			max(luma, cyan_signal * 1.45));
	float use_sparse_source_logic = step(0.001, source_cyan_compression);
	float authored_highlight = mix(sparse_highlight, preserved_core,
			step(0.001, core_preservation));
	return mix(legacy_highlight, authored_highlight, use_sparse_source_logic)
			* sample_color.a;
}

vec3 apply_cool_highlight_shoulder(
		vec3 color,
		vec3 sampled_source,
		float transparent_effect_gate) {
	float value = max(color.r, max(color.g, color.b));
	float excess = max(0.0, value - highlight_shoulder_start);
	float shoulder_value = value - excess
			+ excess / (1.0 + excess * highlight_shoulder_strength);
	float scale = shoulder_value / max(value, 0.001);
	float shoulder_gate = step(0.001, source_cyan_compression)
			* max(step(0.12, cool_source_presence(sampled_source)),
					clamp(transparent_effect_gate, 0.0, 1.0));
	float core_protection = biolume_core_mask(sampled_source);
	shoulder_gate *= 1.0 - core_protection;
	vec3 shouldered = mix(color, color * scale, shoulder_gate);
	return mix(shouldered, shouldered * cool_output_gain, shoulder_gate);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (branch_motion_enabled > 0.5 && branch_group_count > 0) {
		source = sample_branch_texture(UV);
	}
	vec2 edge_px = TEXTURE_PIXEL_SIZE;
	float alpha_left = texture(TEXTURE, UV - vec2(edge_px.x, 0.0)).a;
	float alpha_right = texture(TEXTURE, UV + vec2(edge_px.x, 0.0)).a;
	float alpha_above = texture(TEXTURE, UV - vec2(0.0, edge_px.y)).a;
	float alpha_below_edge = texture(TEXTURE, UV + vec2(0.0, edge_px.y)).a;
	float neighbor_min = min(min(alpha_left, alpha_right),
			min(alpha_above, alpha_below_edge));
	float inside_edge = source.a * (1.0 - neighbor_min);
	vec2 px = TEXTURE_PIXEL_SIZE * halo_radius;
	float core = emission_core(source);
	float local_pulse_phase = glow_pulse_phase + UV.x * 2.7 + UV.y * 1.3;
	float pulse_shape = 0.5 + 0.5 * sin(local_pulse_phase * 1.71);
	float pulse_wave = sin(TIME * glow_pulse_speed + local_pulse_phase);
	float pulse_detail = sin(
		TIME * glow_pulse_speed * 0.63
		- local_pulse_phase * 1.31 + 0.9);
	float pulse = 1.0 + (pulse_wave * 0.78 + pulse_detail * 0.22)
			* glow_pulse_strength * mix(0.42, 1.0, pulse_shape);
	vec2 source_pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 twinkle_cell = floor(source_pixel / 3.0);
	float twinkle_seed = stable_hash(twinkle_cell);
	float selected_point = step(1.0 - point_twinkle_density, twinkle_seed)
			* inside_edge;
	float twinkle_wave = 0.5 + 0.5 * sin(
			TIME * point_twinkle_speed + point_twinkle_phase
			+ twinkle_seed * 6.2831853);
	twinkle_wave *= twinkle_wave;
	float cluster_wave = 0.5 + 0.5 * sin(
			TIME * cluster_breathe_speed + cluster_breathe_phase);
	float special_glow = selected_point * twinkle_wave * point_twinkle_strength
			+ cluster_wave * cluster_breathe_strength;
	float pulsed_core = core * (pulse + special_glow);
	float halo = 0.0;
	halo = max(halo, emission_core(texture(TEXTURE, UV + vec2(px.x, 0.0))));
	halo = max(halo, emission_core(texture(TEXTURE, UV - vec2(px.x, 0.0))));
	halo = max(halo, emission_core(texture(TEXTURE, UV + vec2(0.0, px.y))));
	halo = max(halo, emission_core(texture(TEXTURE, UV - vec2(0.0, px.y))));
	halo = max(halo, emission_core(texture(TEXTURE, UV + px)));
	halo = max(halo, emission_core(texture(TEXTURE, UV - px)));
	halo = max(halo, emission_core(texture(TEXTURE, UV + vec2(px.x, -px.y))));
	halo = max(halo, emission_core(texture(TEXTURE, UV + vec2(-px.x, px.y))));

	float halo_only = max(0.0, halo - core) * halo_strength;

	vec3 graded_source = grade_embedded_cyan(source.rgb);
	float preserved_core = biolume_core_mask(source.rgb);
	float source_luma = dot(graded_source, vec3(0.2126, 0.7152, 0.0722));
	float palette_lerp = smoothstep(0.12, 0.72, source_luma);
	vec3 oasis_palette = mix(shadow_palette.rgb, sunlit_palette.rgb, palette_lerp);
	oasis_palette *= mix(0.78, 1.14, source_luma);
	vec3 local_ambient = mix(
			ambient_tint.rgb, vec3(1.0), preserved_core * 0.78);
	vec3 shaded = mix(
			graded_source * local_ambient * base_brightness,
			oasis_palette * base_brightness,
			palette_strength * (1.0 - preserved_core * 0.90));
	float vertical_air = mix(1.0, 0.42, smoothstep(0.08, 0.92, UV.y));
	float emission_protection = 1.0 - core * 0.65;
	float depth_air_mix = atmosphere_strength * vertical_air * emission_protection;
	float edge_air_mix = inside_edge * edge_integration_strength
			* (1.0 - core * 0.72);
	shaded = mix(shaded, atmosphere_color.rgb,
			clamp(depth_air_mix + edge_air_mix, 0.0, 0.3));
	vec3 solid_color = shaded + glow_color.rgb * pulsed_core * emission_strength;
	solid_color += glow_color.rgb * core * special_glow * 0.20;
	float edge_motion_phase = TIME * sway_speed * 1.47 + sway_phase
			+ UV.x * 2.4 - UV.y * 0.8;
	float edge_motion = 0.5 + 0.5 * sin(edge_motion_phase);
	solid_color += glow_color.rgb * inside_edge * edge_motion_strength
			* edge_motion * (1.0 - core * 0.72);

	float root_contact_zone = smoothstep(
			contact_start, min(contact_start + 0.18, 0.98), UV.y);
	float alpha_below_1 = texture(
			TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
	float alpha_below_2 = texture(
			TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a;
	float solid_root_face = source.a * (1.0 - alpha_below_1)
			* root_contact_zone;
	float solid_root_lip = source.a * alpha_below_1 * (1.0 - alpha_below_2)
			* root_contact_zone;
	float sediment_mask = solid_root_lip * sediment_strength;
	solid_color = mix(solid_color, sediment_color.rgb, sediment_mask * 0.46);
	vec3 root_merge_color = mix(contact_color.rgb, reflection_color.rgb, 0.34);
	solid_color = mix(
			solid_color, root_merge_color,
			solid_root_face * root_merge_strength);
	solid_color *= 1.0 - solid_root_face * contact_strength * 0.08;

	float alpha_up_1 = texture(
			TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
	float alpha_up_2 = texture(
			TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a;
	float alpha_up_3 = texture(
			TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a;
	float transparent_pixel = 1.0 - source.a;
	float contact_mask = transparent_pixel * alpha_up_1
			* root_contact_zone * contact_strength;
	float submerged_fringe = transparent_pixel * (1.0 - alpha_up_1)
			* max(alpha_up_2, alpha_up_3 * 0.44)
			* root_contact_zone;
	float reflection_break = step(0.28,
			fract(sin(dot(floor(UV / TEXTURE_PIXEL_SIZE), vec2(0.91, 1.73))) * 91.17));
	float reflection_mask = submerged_fringe
			* reflection_strength * reflection_break;

	float halo_out_alpha = halo_only * halo_alpha * mix(1.0, pulse, 0.62);
	float contact_alpha = contact_mask;
	float reflection_alpha = reflection_mask * 0.52;
	float transparent_alpha = max(halo_out_alpha, max(contact_alpha, reflection_alpha));
	float effect_weight = halo_out_alpha + contact_alpha + reflection_alpha;
	vec3 transparent_color = (
			glow_color.rgb * halo_strength * halo_out_alpha
			+ contact_color.rgb * contact_alpha
			+ reflection_color.rgb * reflection_alpha) / max(effect_weight, 0.001);
	float output_alpha = max(source.a, transparent_alpha);
	vec3 output_color = mix(transparent_color, solid_color, source.a);
	output_color = apply_cool_highlight_shoulder(
			output_color, source.rgb, transparent_alpha);
	COLOR = vec4(max(output_color, vec3(0.0)), output_alpha);
}
