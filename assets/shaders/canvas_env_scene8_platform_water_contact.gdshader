shader_type canvas_item;
render_mode unshaded, blend_mix;

// A narrow mask-driven pressure line below Scene8's floating platform. The
// platform shader owns the waterline cut; this layer adds only one logical row
// of dark displacement and one broken row of shared-wave crest.

uniform sampler2D platform_texture : filter_nearest, repeat_disable;

group_uniforms layout;
uniform vec2 size_px = vec2(1984.0, 24.0);
uniform vec2 contact_origin_px = vec2(-32.0, 802.0);
uniform vec2 platform_origin_px = vec2(88.0, 166.0);
uniform vec2 platform_rect_size_px = vec2(288.0, 188.0);
uniform vec2 platform_node_scale = vec2(6.0, 6.0);
uniform vec2 pixel_grid = vec2(320.0, 180.0);
uniform float horizon_y : hint_range(0.35, 0.75, 0.005) = 0.52;
group_uniforms;

group_uniforms platform_waterline;
uniform float platform_alpha_threshold : hint_range(0.0, 1.0, 0.001) = 0.03;
uniform float surface_bottom_row : hint_range(0.0, 188.0) = 103.0;
uniform float shallow_wall_rows : hint_range(1.0, 8.0) = 4.0;
uniform float edge_variation_rows : hint_range(0.0, 2.0) = 1.0;
uniform float ice_block_width : hint_range(3.0, 16.0) = 7.0;
uniform float contact_cell_px : hint_range(4.0, 8.0, 1.0) = 6.0;
uniform float shadow_rows : hint_range(1.0, 2.0, 1.0) = 1.0;
uniform float crest_rows : hint_range(1.0, 2.0, 1.0) = 1.0;
uniform float line_cell_width_px : hint_range(48.0, 120.0, 6.0) = 78.0;
uniform float shadow_line_coverage : hint_range(0.5, 0.95, 0.01) = 0.82;
uniform float crest_line_coverage : hint_range(0.2, 0.65, 0.01) = 0.42;
group_uniforms;

group_uniforms contact_palette;
uniform vec4 pressure_shadow_color : source_color = vec4(0.008, 0.035, 0.09, 1.0);
uniform vec4 contact_crest_color : source_color = vec4(0.12, 0.37, 0.52, 1.0);
uniform vec4 aurora_crest_color : source_color = vec4(0.22, 0.56, 0.68, 1.0);
uniform float pressure_shadow_alpha : hint_range(0.0, 1.0) = 0.74;
uniform float contact_crest_alpha : hint_range(0.0, 1.0) = 0.58;
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


float stable_line_hash(float value) {
	return scene8_hash21(vec2(value + 37.0, 619.0));
}


float stable_platform_hash(float value) {
	return fract(sin(value * 12.9898) * 43758.5453);
}


float authored_segment(
		float authored_x,
		float coverage,
		float seed_offset) {
	float width = max(line_cell_width_px, 1.0);
	float line_id = floor(authored_x / width);
	float line_position = fract(authored_x / width);
	float spare = max(1.0 - coverage, 0.0);
	float center = 0.5 + (stable_line_hash(line_id + seed_offset) - 0.5)
			* spare * 0.72;
	float half_width = coverage * 0.5;
	return step(center - half_width, line_position)
			* (1.0 - step(center + half_width, line_position));
}


void fragment() {
	vec2 local_px = floor(UV * size_px);
	vec2 authored_px = contact_origin_px + local_px;
	vec2 platform_size = vec2(textureSize(platform_texture, 0));
	float platform_draw_width = platform_rect_size_px.x
			* platform_node_scale.x;
	float platform_uv_x = (authored_px.x - platform_origin_px.x)
			/ max(platform_draw_width, 1.0);
	float source_x = platform_uv_x * platform_size.x;
	float source_column = floor(source_x);
	float ice_block = floor(source_column / max(ice_block_width, 1.0));
	float edge_step = step(0.72, stable_platform_hash(ice_block))
			* edge_variation_rows;
	float visible_bottom_row = surface_bottom_row
			+ shallow_wall_rows + edge_step;
	float source_row_screen_px = platform_rect_size_px.y
			* platform_node_scale.y / max(platform_size.y, 1.0);
	float waterline_global_y = platform_origin_px.y
			+ visible_bottom_row * source_row_screen_px;
	float distance_below = authored_px.y - waterline_global_y;

	vec2 support_uv = vec2(
			(source_column + 0.5) / max(platform_size.x, 1.0),
			(visible_bottom_row - 0.5) / max(platform_size.y, 1.0));
	float source_contact_alpha = step(
			platform_alpha_threshold,
			texture(platform_texture, support_uv).a);
	float inside_platform_x = step(0.0, platform_uv_x)
			* (1.0 - step(1.0, platform_uv_x));

	vec2 fallback_cell = floor(SCREEN_UV * pixel_grid);
	vec2 fallback_pixel_uv = (fallback_cell + 0.5) / pixel_grid;
	vec2 topology_uv = scene8_lake_topology_uv(
			fallback_pixel_uv, SCREEN_UV);
	vec4 topology = sample_lake_topology(topology_uv, fallback_pixel_uv);
	if (topology.r < 0.5) {
		discard;
	}
	vec2 lake_cell = floor(topology_uv * pixel_grid);
	vec3 wave = shared_wave_field(
			lake_cell, clamp(topology.b, 0.0, 1.0), motion_time());

	float shadow_depth_px = contact_cell_px * shadow_rows;
	float crest_depth_px = contact_cell_px * crest_rows;
	float shadow_band = step(0.0, distance_below)
			* (1.0 - step(shadow_depth_px, distance_below));
	float crest_band = step(shadow_depth_px, distance_below)
			* (1.0 - step(
					shadow_depth_px + crest_depth_px, distance_below));
	float shadow_segment = authored_segment(
			authored_px.x, shadow_line_coverage, 11.0);
	float moved_crest_x = authored_px.x + wave.z * contact_cell_px;
	float crest_segment = authored_segment(
			moved_crest_x, crest_line_coverage, 47.0);
	float platform_support = source_contact_alpha * inside_platform_x;
	float shadow_alpha = shadow_band * shadow_segment
			* platform_support * pressure_shadow_alpha;
	float crest_wave = 0.58 + 0.42 * clamp(wave.x + wave.y * 0.36, 0.0, 1.0);
	float crest_alpha = crest_band * crest_segment
			* platform_support * contact_crest_alpha * crest_wave;
	vec3 crest_color = mix(
			contact_crest_color.rgb, aurora_crest_color.rgb,
			clamp(wave.x * 0.45, 0.0, 0.45));
	vec3 contact_color = mix(
			pressure_shadow_color.rgb, crest_color,
			step(shadow_alpha, crest_alpha));
	COLOR = vec4(contact_color, max(shadow_alpha, crest_alpha));
}
