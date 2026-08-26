shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D platform_texture : filter_nearest, repeat_disable;
uniform vec2 size_px = vec2(1984.0, 18.0);
uniform vec2 contact_origin_px = vec2(-32.0, 824.0);
uniform vec2 platform_origin_px = vec2(-133.165, 234.0);
uniform vec2 platform_rect_size_px = vec2(364.83338, 188.0);
uniform vec2 platform_node_scale = vec2(6.0, 6.0);
uniform float surface_bottom_row = 95.0;
uniform float shallow_wall_rows = 4.0;
uniform float edge_variation_rows = 1.0;
uniform float stone_block_width = 7.0;
uniform float line_cell_width_px = 78.0;
uniform float line_presence : hint_range(0.0, 1.0) = 0.86;
uniform float line_margin_px = 8.0;
uniform float contact_thickness_px : hint_range(3.0, 6.0) = 5.0;
uniform float minimum_thickness_px : hint_range(2.0, 4.0) = 3.0;
uniform float anim_fps : hint_range(4.0, 12.0) = 8.0;
uniform float spring_period_sec : hint_range(5.0, 12.0) = 7.6;
uniform float active_line_ratio : hint_range(0.4, 0.8) = 0.64;
uniform vec4 surface_color : source_color = vec4(0.133, 0.667, 0.6, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.333, 0.8, 0.667, 1.0);
uniform vec4 spring_glow_color : source_color = vec4(0.44, 0.88, 0.72, 1.0);
uniform float ripple_palette_mix : hint_range(0.3, 0.8) = 0.58;
uniform float glow_palette_mix : hint_range(0.2, 0.7) = 0.42;
uniform float contact_alpha : hint_range(0.0, 1.0) = 0.66;


float stable_hash(float value) {
	return fract(sin(value * 12.9898) * 43758.5453);
}


float authored_line_width(float line_id) {
	// A long contact is authored as one long interval. It is never assembled
	// from adjacent short segments, so the animation cannot expose inner seams.
	float width_tier = floor(stable_hash(line_id * 5.71 + 3.4) * 4.0);
	return 24.0 + width_tier * 10.0;
}


float authored_line_start(float line_id, float line_width_px) {
	float free_space = max(
			0.0,
			line_cell_width_px - line_margin_px * 2.0 - line_width_px);
	return line_margin_px + floor(
			stable_hash(line_id * 9.13 + 7.2) * (free_space + 1.0));
}


vec3 contact_event_state(
		float line_id,
		float line_width_px,
		float pixel_time) {
	float cycle_id = floor(pixel_time / spring_period_sec);
	float cycle_frame = floor(mod(pixel_time, spring_period_sec) * anim_fps);
	float participation = stable_hash(
			line_id * 3.17 + cycle_id * 47.11 + 5.3);
	float active_cycle = step(1.0 - active_line_ratio, participation);
	float onset_frames = 1.0 + floor(stable_hash(
			line_id * 11.7 + cycle_id * 7.9 + 2.1) * 4.0);
	float maximum_edge_cut = floor(line_width_px * 0.25);
	float retract_frames = max(
			14.0,
			maximum_edge_cut + 2.0 + floor(stable_hash(
			line_id * 5.9 + cycle_id * 13.1 + 8.4) * 5.0));
	float hold_frames = 6.0 + floor(stable_hash(
			line_id * 17.3 + cycle_id * 3.7 + 1.6) * 5.0);
	float recover_frames = max(
			17.0,
			maximum_edge_cut + 4.0 + floor(stable_hash(
			line_id * 23.9 + cycle_id * 5.1 + 9.2) * 6.0));
	float local_frame = cycle_frame - onset_frames;
	float event_frames = retract_frames + hold_frames + recover_frames;
	float edge_cut_px = 0.0;
	float event_active = 0.0;
	float palette_stage = 0.0;
	if (active_cycle > 0.5
			&& local_frame >= 0.0
			&& local_frame < event_frames) {
		event_active = 1.0;
		if (local_frame < retract_frames) {
			edge_cut_px = floor(
					local_frame * (maximum_edge_cut + 1.0)
					/ retract_frames);
		} else if (local_frame < retract_frames + hold_frames) {
			edge_cut_px = maximum_edge_cut;
		} else {
			float recovery_frame = local_frame - retract_frames - hold_frames;
			edge_cut_px = maximum_edge_cut - floor(
					recovery_frame * (maximum_edge_cut + 1.0)
					/ recover_frames);
		}
		edge_cut_px = clamp(edge_cut_px, 0.0, maximum_edge_cut);
		if (local_frame < 3.0) {
			palette_stage = 2.0;
		} else if (edge_cut_px < maximum_edge_cut * 0.75) {
			palette_stage = 1.0;
		}
	}
	return vec3(edge_cut_px, event_active, palette_stage);
}


void fragment() {
	vec2 local_px = floor(UV * size_px);
	float global_x = contact_origin_px.x + local_px.x;
	vec2 platform_size = vec2(textureSize(platform_texture, 0));
	float platform_uv_x = (global_x - platform_origin_px.x)
			/ (platform_rect_size_px.x * platform_node_scale.x);
	float source_x = platform_uv_x * platform_size.x;
	float source_column = floor(source_x);
	float stone_block = floor(source_column / stone_block_width);
	float edge_step = step(0.72, stable_hash(stone_block))
			* edge_variation_rows;
	float platform_bottom_source = surface_bottom_row + shallow_wall_rows
			+ edge_step;
	float source_row_screen_px = platform_rect_size_px.y
			* platform_node_scale.y / platform_size.y;
	float platform_bottom_global = platform_origin_px.y
			+ platform_bottom_source * source_row_screen_px;
	float platform_bottom_local = round(
			platform_bottom_global - contact_origin_px.y);

	vec2 platform_uv = vec2(
			(source_column + 0.5) / platform_size.x,
			(platform_bottom_source - 0.5) / platform_size.y);
	float source_contact_alpha = texture(platform_texture, platform_uv).a;
	float inside_platform_x = step(0.0, platform_uv_x)
			* (1.0 - step(1.0, platform_uv_x));

	float line_id = floor(global_x / line_cell_width_px);
	float line_width_px = authored_line_width(line_id);
	float line_start_px = authored_line_start(line_id, line_width_px);
	float line_local_px = floor(mod(global_x, line_cell_width_px));
	float line_open = step(
			1.0 - line_presence,
			stable_hash(line_id * 2.31 + 19.7));
	float pixel_time = floor(TIME * anim_fps) / anim_fps;
	vec3 event_state = contact_event_state(
			line_id, line_width_px, pixel_time);
	float edge_cut_px = event_state.x;
	float visible_start_px = line_start_px + edge_cut_px;
	float visible_end_px = line_start_px + line_width_px - edge_cut_px;
	float single_line_mask = step(visible_start_px, line_local_px)
			* (1.0 - step(visible_end_px, line_local_px));
	float maximum_edge_cut = max(1.0, floor(line_width_px * 0.25));
	float retraction_ratio = edge_cut_px / maximum_edge_cut;
	float active_thickness_px = max(
			minimum_thickness_px,
			contact_thickness_px - floor(retraction_ratio * 3.0));
	float distance_below = local_px.y - platform_bottom_local;
	float band = step(0.0, distance_below)
			* (1.0 - step(active_thickness_px, distance_below));
	float ripple_stage = step(0.5, event_state.z);
	float glow_stage = step(1.5, event_state.z);
	vec3 contact_ripple_color = mix(
			surface_color.rgb, ripple_color.rgb, ripple_palette_mix);
	vec3 contact_glow_color = mix(
			contact_ripple_color, spring_glow_color.rgb, glow_palette_mix);
	vec3 spring_color = mix(
			surface_color.rgb, contact_ripple_color, ripple_stage);
	spring_color = mix(spring_color, contact_glow_color, glow_stage);
	float palette_alpha = mix(0.84, 0.90, ripple_stage);
	palette_alpha = mix(palette_alpha, 0.94, glow_stage);
	float accepted_static_alpha = band * line_open * single_line_mask
			* source_contact_alpha
			* inside_platform_x * contact_alpha * palette_alpha;

	COLOR = vec4(spring_color, accepted_static_alpha);
}
