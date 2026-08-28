shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene8 repaired-ref48 reflection. A continuous lake-depth region samples the
// live translucent aurora after its slow motion and sky blend. A quiet floor
// keeps the colored body readable while the shared water ridge breaks it up.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms layout;
uniform vec2 pixel_grid = vec2(320.0, 180.0);
uniform float horizon_y : hint_range(0.35, 0.75, 0.005) = 0.52;
uniform float reflection_coverage_depth : hint_range(0.55, 0.90, 0.01) = 0.86;
uniform float shore_reflection_clearance : hint_range(0.05, 0.45, 0.01) = 0.24;
uniform float reflection_start_depth : hint_range(0.0, 0.35, 0.01) = 0.12;
uniform float reflection_end_depth : hint_range(0.55, 0.90, 0.01) = 0.80;
uniform float reflection_source_top_y : hint_range(0.02, 0.24, 0.005) = 0.10;
uniform float reflection_source_bottom_y : hint_range(0.20, 0.50, 0.005) = 0.41;
uniform float reflection_center_x : hint_range(0.35, 0.65, 0.01) = 0.50;
uniform float reflection_horizontal_stretch : hint_range(1.0, 1.4, 0.01) = 1.10;
uniform float reflection_floor : hint_range(0.0, 0.5, 0.01) = 0.24;
group_uniforms;

group_uniforms lake_topology_data;
uniform sampler2D lake_topology : repeat_disable, filter_nearest;
uniform bool use_lake_topology = false;
uniform vec2 topology_base_origin_uv = vec2(0.0);
uniform vec2 topology_base_size_uv = vec2(1.0);
uniform vec2 topology_current_origin_uv = vec2(0.0);
uniform vec2 topology_current_size_uv = vec2(1.0);
group_uniforms;

#include "res://assets/shaders/canvas_env_scene8_shared_water_wave.gdshaderinc"

group_uniforms sampled_light;
uniform float reflection_strength : hint_range(0.0, 0.70, 0.01) = 0.43;
uniform float reflection_saturation : hint_range(0.5, 1.6, 0.01) = 1.08;
uniform float reflection_value_ceiling : hint_range(0.3, 1.0, 0.01) = 0.78;
uniform float chroma_gate_low : hint_range(0.0, 0.3, 0.005) = 0.055;
uniform float chroma_gate_high : hint_range(0.05, 0.6, 0.005) = 0.18;
uniform float deep_color_absorption : hint_range(0.0, 0.6, 0.01) = 0.12;
group_uniforms;


float continuous_reflection_zone(float depth) {
	float enter = smoothstep(
			reflection_start_depth,
			reflection_start_depth + 0.045,
			depth);
	float leave = 1.0 - smoothstep(
			reflection_end_depth - 0.07,
			reflection_end_depth,
			depth);
	return enter * leave;
}


float source_y_from_depth(float depth) {
	float reflected_depth = clamp(
			(depth - reflection_start_depth)
			/ max(reflection_end_depth - reflection_start_depth, 0.001),
			0.0, 1.0);
	return mix(
			reflection_source_bottom_y,
			reflection_source_top_y,
			reflected_depth);
}


void fragment() {
	vec2 local_cell = floor(UV * pixel_grid);
	vec2 local_pixel_uv = (local_cell + 0.5) / pixel_grid;
	vec2 topology_uv = scene8_lake_topology_uv(local_pixel_uv, SCREEN_UV);
	vec2 cell = floor(topology_uv * pixel_grid);
	vec4 topology = sample_lake_topology(topology_uv, local_pixel_uv);
	if (topology.r < 0.5) {
		discard;
	}

	float depth = clamp(topology.b, 0.0, 1.0);
	float reflection_zone = continuous_reflection_zone(depth);
	if (reflection_zone <= 0.0) {
		discard;
	}
	vec3 shared_wave = shared_wave_field(cell, depth, motion_time());
	float reflection_wave = mix(reflection_floor, 1.0, clamp(
			shared_wave.x + shared_wave.y * 0.35, 0.0, 1.0));
	float x_offset_cells = round(clamp(
			shared_wave.z,
			-wave_max_offset_cells,
			wave_max_offset_cells));

	float source_y = source_y_from_depth(depth);
	float source_pixel_y = (
			floor(source_y * pixel_grid.y) + 0.5) / pixel_grid.y;
	float stretched_source_x = reflection_center_x
			+ (SCREEN_UV.x - reflection_center_x)
			/ reflection_horizontal_stretch;
	vec2 screen_sample_uv = vec2(
			stretched_source_x + x_offset_cells / pixel_grid.x,
			source_pixel_y);
	screen_sample_uv = clamp(screen_sample_uv, vec2(0.001), vec2(0.999));
	vec3 source = textureLod(screen_tex, screen_sample_uv, 0.0).rgb;
	float luma = dot(source, vec3(0.2126, 0.7152, 0.0722));
	float source_max = max(source.r, max(source.g, source.b));
	float source_min = min(source.r, min(source.g, source.b));
	float relative_saturation = (source_max - source_min)
			/ max(source_max, 0.0001);
	float cool_chroma = max(source.g, source.b) - source.r;
	float star_rejection = smoothstep(0.20, 0.38, relative_saturation)
			* (1.0 - smoothstep(0.60, 0.88, luma));
	float aurora_presence = smoothstep(
			chroma_gate_low, chroma_gate_high, cool_chroma)
			* star_rejection;

	vec3 saturated_source = mix(vec3(luma), source, reflection_saturation);
	float value_scale = min(
			1.0, reflection_value_ceiling
			/ max(max(saturated_source.r, saturated_source.g),
					max(saturated_source.b, 0.0001)));
	saturated_source = clamp(
			saturated_source * value_scale, vec3(0.0), vec3(1.0));
	vec3 depth_absorption = mix(
			vec3(0.96, 1.0, 1.03),
			vec3(1.0 - deep_color_absorption, 0.94, 1.04),
			smoothstep(0.18, reflection_end_depth, depth));
	vec3 reflected = clamp(
			saturated_source * depth_absorption, vec3(0.0), vec3(1.0));

	float brightness_presence = smoothstep(0.008, 0.24, luma);
	float shore_reflection_fade = smoothstep(
			shore_reflection_clearance,
			shore_reflection_clearance + 0.12,
			topology.g);
	float depth_fade = mix(
			1.0, 0.72,
			smoothstep(0.28, reflection_end_depth, depth));
	float alpha = reflection_strength * brightness_presence
			* shore_reflection_fade * depth_fade
			* reflection_wave * aurora_presence * reflection_zone;
	COLOR = vec4(reflected, alpha);
}
