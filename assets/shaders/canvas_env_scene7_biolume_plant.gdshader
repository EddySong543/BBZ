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
uniform float sway_strength_px : hint_range(0.0, 1.0) = 0.0;
uniform float sway_speed : hint_range(0.0, 1.0) = 0.42;
uniform float sway_phase = 0.0;
uniform float sway_anchor_y : hint_range(0.35, 0.9) = 0.68;
uniform float secondary_sway_ratio : hint_range(0.0, 0.6) = 0.34;
uniform float vertical_sway_ratio : hint_range(0.0, 0.2) = 0.08;
uniform float edge_motion_strength : hint_range(0.0, 0.1) = 0.0;
uniform float glow_pulse_strength : hint_range(0.0, 0.25) = 0.0;
uniform float glow_pulse_speed : hint_range(0.0, 1.5) = 0.5;
uniform float glow_pulse_phase = 0.0;

void vertex() {
	float anchored_sway = 1.0 - smoothstep(0.08, sway_anchor_y, UV.y);
	float spatial_phase = (UV.x - 0.5) * 1.35;
	float primary = sin(TIME * sway_speed + sway_phase + spatial_phase);
	float secondary = sin(
		TIME * sway_speed * 0.61 + sway_phase * 1.37 + 1.2
		- spatial_phase * 0.71);
	float tip_flutter = sin(
		TIME * sway_speed * 1.47 + sway_phase * 0.73
		+ spatial_phase * 1.8);
	float lateral_sway = primary
		+ secondary * secondary_sway_ratio
		+ tip_flutter * 0.14;
	VERTEX.x += lateral_sway * sway_strength_px * anchored_sway;
	VERTEX.y += secondary
		* sway_strength_px
		* vertical_sway_ratio
		* anchored_sway;
}

float cool_source_presence(vec3 color) {
	float cool_value = max(color.g, color.b);
	float warm_value = max(color.r, min(color.g, color.b) * 0.34);
	return smoothstep(0.08, 0.34, cool_value - warm_value);
}

vec3 grade_embedded_cyan(vec3 color) {
	float cool_value = max(color.g, color.b);
	float compression_range = max(0.08,
			source_cyan_value_ceiling - source_cyan_value_start);
	float bright_cool = cool_source_presence(color)
			* smoothstep(source_cyan_value_start,
					source_cyan_value_start + 0.12, cool_value);
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
	return mix(color, compressed, bright_cool);
}

float emission_core(vec4 sample_color) {
	float cool_value = max(sample_color.g, sample_color.b);
	float knee = max(0.01, emission_soft_knee);
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
	return mix(legacy_highlight, sparse_highlight, use_sparse_source_logic)
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
	vec3 shouldered = mix(color, color * scale, shoulder_gate);
	return mix(shouldered, shouldered * cool_output_gain, shoulder_gate);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
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
	float pulsed_core = core * pulse;
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
	float source_luma = dot(graded_source, vec3(0.2126, 0.7152, 0.0722));
	float palette_lerp = smoothstep(0.12, 0.72, source_luma);
	vec3 oasis_palette = mix(shadow_palette.rgb, sunlit_palette.rgb, palette_lerp);
	oasis_palette *= mix(0.78, 1.14, source_luma);
	vec3 shaded = mix(
			graded_source * ambient_tint.rgb * base_brightness,
			oasis_palette * base_brightness,
			palette_strength);
	float vertical_air = mix(1.0, 0.42, smoothstep(0.08, 0.92, UV.y));
	float emission_protection = 1.0 - core * 0.65;
	float depth_air_mix = atmosphere_strength * vertical_air * emission_protection;
	float edge_air_mix = inside_edge * edge_integration_strength
			* (1.0 - core * 0.72);
	shaded = mix(shaded, atmosphere_color.rgb,
			clamp(depth_air_mix + edge_air_mix, 0.0, 0.3));
	vec3 solid_color = shaded + glow_color.rgb * pulsed_core * emission_strength;
	float edge_motion_phase = TIME * sway_speed * 1.47 + sway_phase
			+ UV.x * 2.4 - UV.y * 0.8;
	float edge_motion = 0.5 + 0.5 * sin(edge_motion_phase);
	solid_color += glow_color.rgb * inside_edge * edge_motion_strength
			* edge_motion * (1.0 - core * 0.72);

	float root_zone = smoothstep(contact_start, 1.0, UV.y);
	float alpha_below = texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y * 1.5)).a;
	float lower_edge = source.a * (1.0 - alpha_below) * root_zone;
	float sediment_mask = lower_edge * sediment_strength;
	solid_color = mix(solid_color, sediment_color.rgb, sediment_mask * 0.55);
	vec3 root_merge_color = mix(sediment_color.rgb, reflection_color.rgb, 0.42);
	solid_color = mix(solid_color, root_merge_color,
			lower_edge * root_merge_strength);
	solid_color *= 1.0 - lower_edge * contact_strength * 0.06;

	float alpha_up_1 = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 1.5)).a;
	float alpha_up_2 = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a;
	float alpha_up_3 = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 5.0)).a;
	float transparent_pixel = 1.0 - source.a;
	float contact_mask = transparent_pixel * max(alpha_up_1, alpha_up_2 * 0.68)
			* root_zone * contact_strength;
	float reflection_break = step(0.28,
			fract(sin(dot(floor(UV / TEXTURE_PIXEL_SIZE), vec2(0.91, 1.73))) * 91.17));
	float reflection_mask = transparent_pixel * max(alpha_up_2 * 0.72, alpha_up_3 * 0.42)
			* root_zone * reflection_strength * reflection_break;

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
