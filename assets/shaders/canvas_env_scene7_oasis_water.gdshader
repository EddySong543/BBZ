shader_type canvas_item;
render_mode unshaded;

// Scene7 foreground spring pool. The stable emerald reflection is the artwork;
// animation only bends that artwork with slow, source-centred spring rings.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms layout;
uniform vec2 size_px = vec2(1984.0, 224.0);
uniform vec2 screen_px = vec2(1920.0, 1080.0);
uniform float px_size : hint_range(1.0, 8.0) = 4.0;
uniform float perspective_y : hint_range(1.0, 6.0) = 2.8;
group_uniforms;

group_uniforms reflection;
uniform float reflection_height_px : hint_range(160.0, 720.0) = 540.0;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.54;
uniform float reflection_levels : hint_range(2.0, 16.0) = 9.0;
uniform vec4 reflection_tint : source_color = vec4(0.04, 0.96, 0.82, 1.0);
uniform float reflection_colorize : hint_range(0.0, 1.0) = 0.68;
uniform float slice_px_far : hint_range(2.0, 12.0) = 4.0;
uniform float slice_px_near : hint_range(4.0, 20.0) = 10.0;
uniform float radial_distortion_px : hint_range(0.0, 20.0) = 4.0;
uniform float breakup_px : hint_range(16.0, 160.0) = 76.0;
uniform float breakup_strength : hint_range(0.0, 1.0) = 0.10;
group_uniforms;

group_uniforms character_reflection;
uniform sampler2D p1_reflection_tex : filter_nearest, repeat_disable;
uniform sampler2D p2_reflection_tex : filter_nearest, repeat_disable;
uniform vec4 p1_reflection_rect = vec4(0.0);
uniform vec4 p2_reflection_rect = vec4(0.0);
uniform float p1_reflection_foot_y = 0.0;
uniform float p2_reflection_foot_y = 0.0;
uniform float character_waterline_y = 0.0;
uniform float character_reflection_strength : hint_range(0.0, 1.0) = 0.30;
uniform float character_reflection_vertical_scale : hint_range(0.5, 2.0) = 1.08;
uniform float character_reflection_saturation : hint_range(0.0, 1.0) = 0.64;
uniform vec4 character_reflection_tint : source_color = vec4(0.35, 0.92, 0.74, 1.0);
uniform float character_reflection_fade_start : hint_range(0.0, 1.0) = 0.58;
group_uniforms;

group_uniforms palette;
uniform vec4 surface_color : source_color = vec4(0.015, 0.62, 0.56, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.004, 0.43, 0.46, 1.0);
uniform vec4 deep_color : source_color = vec4(0.0, 0.17, 0.27, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.18, 0.90, 0.70, 1.0);
uniform vec4 spring_glow_color : source_color = vec4(0.42, 1.0, 0.78, 1.0);
uniform float depth_curve : hint_range(0.2, 4.0) = 1.08;
uniform float row_contrast : hint_range(0.0, 0.3) = 0.026;
group_uniforms;

group_uniforms spring_motion;
uniform float anim_fps : hint_range(1.0, 20.0) = 8.0;
uniform vec2 main_source = vec2(0.52, -0.06);
uniform vec2 secondary_source_a = vec2(0.20, 0.56);
uniform vec2 secondary_source_b = vec2(0.80, 0.48);
uniform float main_period_sec : hint_range(2.0, 12.0) = 7.6;
uniform float micro_period_sec : hint_range(3.0, 16.0) = 11.0;
uniform float ring_spacing : hint_range(0.08, 0.6) = 0.34;
uniform float ring_width : hint_range(0.005, 0.08) = 0.024;
uniform float main_ring_strength : hint_range(0.0, 1.0) = 0.38;
uniform float micro_ring_strength : hint_range(0.0, 1.0) = 0.10;
uniform float caustic_strength : hint_range(0.0, 0.5) = 0.10;
group_uniforms;

group_uniforms shore;
uniform vec4 shore_dark : source_color = vec4(0.002, 0.10, 0.16, 1.0);
uniform vec4 shore_light : source_color = vec4(0.34, 0.88, 0.67, 1.0);
uniform float shore_px : hint_range(1.0, 12.0) = 4.0;
uniform float shore_cluster_spacing_px : hint_range(24.0, 180.0) = 104.0;
uniform float shore_cluster_density : hint_range(0.0, 0.7) = 0.20;
uniform float shore_cluster_cycle_sec : hint_range(2.0, 12.0) = 9.0;
uniform float shore_light_strength : hint_range(0.0, 1.0) = 0.30;
group_uniforms;


float hash21(vec2 p) {
	p = mod(p, vec2(511.0, 257.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float spring_distance(vec2 uv, vec2 source) {
	return length((uv - source) * vec2(1.0, perspective_y));
}


float ring_mask(float distance_to_source, float time_phase, float phase_offset) {
	float phase = fract(
			distance_to_source / max(ring_spacing, 0.001)
			- time_phase + phase_offset);
	float edge_distance = min(phase, 1.0 - phase);
	return 1.0 - smoothstep(ring_width, ring_width + 0.034, edge_distance);
}


float arc_modulation(vec2 uv, vec2 source, float distance_to_source) {
	vec2 delta = uv - source;
	float angle = atan(delta.y, delta.x);
	float ring_id = floor(distance_to_source / max(ring_spacing, 0.001));
	float broad_arc = 0.5 + 0.5 * sin(angle * 3.0 + ring_id * 1.73);
	return mix(0.62, 1.0, smoothstep(0.18, 0.82, broad_arc));
}


float signed_radial_wave(
		vec2 uv,
		vec2 source,
		float distance_to_source,
		float time_phase,
		float phase_offset) {
	vec2 delta = uv - source;
	float horizontal_direction = delta.x / max(length(delta), 0.001);
	float envelope = 1.0 - smoothstep(0.18, 1.28, distance_to_source);
	float wave = sin(TAU * (
			distance_to_source / max(ring_spacing, 0.001)
			- time_phase + phase_offset));
	return wave * horizontal_direction * envelope;
}


float reflection_rect_mask(vec2 point_px, vec4 rect_px) {
	vec2 lower = step(rect_px.xy, point_px);
	vec2 upper = step(point_px, rect_px.xy + rect_px.zw);
	float valid_size = step(1.0, rect_px.z) * step(1.0, rect_px.w);
	return lower.x * lower.y * upper.x * upper.y * valid_size;
}


vec3 emerald_reflection(vec3 source_rgb) {
	float luma = dot(source_rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 palette_reflection = mix(
			deep_color.rgb,
			surface_color.rgb,
			smoothstep(0.025, 0.58, luma));
	palette_reflection = mix(
			palette_reflection,
			spring_glow_color.rgb,
			smoothstep(0.62, 0.92, luma) * 0.42);
	vec3 tinted_source = source_rgb * reflection_tint.rgb;
	return mix(tinted_source, palette_reflection, reflection_colorize);
}


void fragment() {
	float t = floor(TIME * anim_fps) / anim_fps;
	vec2 px = floor(UV * size_px / px_size) * px_size + px_size * 0.5;
	vec2 quv = px / size_px;
	float depth = pow(clamp(quv.y, 0.0, 1.0), depth_curve);
	float main_time = t / max(main_period_sec, 0.001);

	// Horizontal bands preserve pixel-art structure while mapping the entire
	// 540px midground into the 224px pool instead of truncating it.
	float band_h = mix(slice_px_far, slice_px_near, depth);
	float band_id = floor(px.y / band_h);
	float band_y = (band_id + 0.5) * band_h;
	vec2 band_uv = vec2(quv.x, band_y / size_px.y);
	float main_distance = spring_distance(band_uv, main_source);
	float radial_wave = signed_radial_wave(
			band_uv, main_source, main_distance, main_time, 0.0);
	float band_shift = floor(
			radial_wave * radial_distortion_px / px_size) * px_size;
	float block_w = mix(breakup_px * 0.82, breakup_px * 1.18, depth);
	float block_id = floor(px.x / block_w);
	float block_shift = floor(
			(hash21(vec2(block_id, band_id + 31.0)) - 0.5)
			* radial_distortion_px * breakup_strength / px_size) * px_size;

	vec2 suv = SCREEN_UV + (quv - UV) * size_px / screen_px;
	float waterline = suv.y - quv.y * size_px.y / screen_px.y;
	float reflected_depth_px = band_y / size_px.y * reflection_height_px;
	vec2 ruv = vec2(
			suv.x + (band_shift + block_shift) / screen_px.x,
			waterline - reflected_depth_px / screen_px.y);
	ruv.x = clamp(ruv.x, 0.001, 0.999);
	ruv.y = clamp(ruv.y, 0.001, max(waterline - 0.001, 0.001));
	vec3 reflection = emerald_reflection(textureLod(screen_tex, ruv, 0.0).rgb);
	reflection = floor(reflection * reflection_levels + 0.5) / reflection_levels;

	vec3 water_base = mix(
			surface_color.rgb, shallow_color.rgb, smoothstep(0.0, 0.44, depth));
	water_base = mix(water_base, deep_color.rgb, smoothstep(0.48, 1.0, depth));
	float row_tone = mix(
			1.0 - row_contrast,
			1.0 + row_contrast,
			hash21(vec2(band_id, 73.0)));
	water_base *= row_tone;
	float reflection_mix = reflection_strength * mix(1.0, 0.56, depth);
	vec3 col = mix(water_base, reflection, reflection_mix);

	// One coherent spring source: a broad trough and narrow luminous crest.
	main_distance = spring_distance(quv, main_source);
	float ring_envelope = 1.0 - smoothstep(0.20, 1.26, main_distance);
	float crest = ring_mask(main_distance, main_time, 0.0)
			* arc_modulation(quv, main_source, main_distance)
			* ring_envelope;
	float trough = ring_mask(main_distance, main_time, 0.12) * ring_envelope;
	col = mix(col, deep_color.rgb, trough * 0.075);
	col = mix(col, ripple_color.rgb, crest * main_ring_strength);
	float spring_halo = 1.0 - smoothstep(0.12, 0.62, main_distance);
	col = mix(col, spring_glow_color.rgb, spring_halo * 0.10);

	// Shallow caustics change phase in place; they never translate like a river.
	float caustic_phase = t / max(micro_period_sec, 0.001) * TAU;
	float caustic_a = sin((quv.x * 5.0 + quv.y * 2.6) * TAU
			+ sin(quv.y * 7.0 * TAU) * 0.42 + caustic_phase);
	float caustic_b = sin((quv.x * -3.2 + quv.y * 5.4) * TAU
			- caustic_phase * 0.73);
	float caustic = smoothstep(1.48, 1.82, caustic_a + caustic_b);
	caustic *= smoothstep(0.10, 0.30, depth)
			* (1.0 - smoothstep(0.82, 1.0, depth));
	col = mix(col, spring_glow_color.rgb, caustic * caustic_strength);

	// Characters render after Stage, so their SubViewport textures are mirrored
	// separately to complete the scene reflection.
	vec2 screen_pos_px = suv * screen_px;
	float char_depth_px = max(screen_pos_px.y - character_waterline_y, 0.0);
	float char_depth_norm = clamp(char_depth_px / max(size_px.y, 1.0), 0.0, 1.0);
	float char_sample_x = screen_pos_px.x + band_shift + block_shift;
	float char_scale = max(character_reflection_vertical_scale, 0.001);
	vec2 p1_source_px = vec2(
			char_sample_x, p1_reflection_foot_y - char_depth_px / char_scale);
	vec2 p2_source_px = vec2(
			char_sample_x, p2_reflection_foot_y - char_depth_px / char_scale);
	vec2 p1_uv = (p1_source_px - p1_reflection_rect.xy)
			/ max(p1_reflection_rect.zw, vec2(1.0));
	vec2 p2_uv = (p2_source_px - p2_reflection_rect.xy)
			/ max(p2_reflection_rect.zw, vec2(1.0));
	float below_water = step(character_waterline_y, screen_pos_px.y);
	float p1_inside = reflection_rect_mask(p1_source_px, p1_reflection_rect)
			* below_water;
	float p2_inside = reflection_rect_mask(p2_source_px, p2_reflection_rect)
			* below_water;
	vec4 p1_sample = texture(
			p1_reflection_tex, clamp(p1_uv, vec2(0.0), vec2(1.0))) * p1_inside;
	vec4 p2_sample = texture(
			p2_reflection_tex, clamp(p2_uv, vec2(0.0), vec2(1.0))) * p2_inside;
	vec4 char_sample = p1_sample + p2_sample * (1.0 - p1_sample.a);
	float char_luma = dot(char_sample.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 char_reflection = mix(
			vec3(char_luma), char_sample.rgb, character_reflection_saturation);
	char_reflection *= character_reflection_tint.rgb;
	char_reflection = floor(
			char_reflection * reflection_levels + 0.5) / reflection_levels;
	float char_fade = 1.0 - smoothstep(
			character_reflection_fade_start, 1.0, char_depth_norm);
	float char_mix = char_sample.a * character_reflection_strength
			* char_fade * mix(1.0, 0.76, depth);
	col = mix(col, char_reflection, char_mix);

	float shore_shadow = 1.0 - step(
			(shore_px + px_size) / size_px.y, quv.y);
	col = mix(col, shore_dark.rgb, shore_shadow * 0.66);
	float shore_cluster = floor(px.x / shore_cluster_spacing_px);
	float shore_local = mod(px.x, shore_cluster_spacing_px);
	float shore_seed = hash21(vec2(shore_cluster, 181.0));
	float shore_active = step(1.0 - shore_cluster_density, shore_seed);
	float shore_length = mix(
			shore_cluster_spacing_px * 0.18,
			shore_cluster_spacing_px * 0.48,
			hash21(vec2(shore_cluster, 223.0)));
	float shore_phase = fract(
			t / shore_cluster_cycle_sec + hash21(vec2(shore_cluster, 307.0)));
	float shore_life = floor((0.5 + 0.5 * sin(shore_phase * TAU)) * 3.0 + 0.5) / 3.0;
	float shore_segment = shore_active * step(shore_local, shore_length) * shore_life;
	float shore_row = (1.0 - step(shore_px / size_px.y, quv.y)) * shore_segment;
	col = mix(col, shore_light.rgb, shore_row * shore_light_strength);

	col = floor(clamp(col, vec3(0.0), vec3(1.0)) * 31.0 + 0.5) / 31.0;
	COLOR = vec4(col, 1.0);
}
