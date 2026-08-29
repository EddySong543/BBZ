shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene8's authored platform contains a deep dark wall below its ice shelf.
// Keep the source asset intact, but let the lake occlude that submerged body so
// only a shallow 4-5 source-row rim remains above the waterline.

uniform float surface_bottom_row : hint_range(0.0, 188.0) = 103.0;
uniform float shallow_wall_rows : hint_range(1.0, 8.0) = 4.0;
uniform float edge_variation_rows : hint_range(0.0, 2.0) = 1.0;
uniform float ice_block_width : hint_range(3.0, 16.0) = 7.0;
uniform vec4 underside_tint : source_color = vec4(0.045, 0.14, 0.24, 1.0);
uniform vec4 wet_edge_tint : source_color = vec4(0.08, 0.27, 0.38, 1.0);
uniform float underside_strength : hint_range(0.0, 1.0) = 0.30;
uniform float wet_edge_strength : hint_range(0.0, 1.0) = 0.48;
uniform float platform_break_amount : hint_range(0.0, 1.0) = 0.0;
uniform float crack_start_row : hint_range(0.0, 188.0) = 90.0;
uniform float crack_end_row : hint_range(0.0, 188.0) = 103.0;
uniform vec4 crack_core_color : source_color = vec4(0.015, 0.07, 0.13, 1.0);
uniform vec4 crack_branch_color : source_color = vec4(0.025, 0.16, 0.23, 1.0);
uniform vec4 crack_glint_color : source_color = vec4(0.22, 0.68, 0.72, 1.0);


float stable_hash(float value) {
	return fract(sin(value * 12.9898) * 43758.5453);
}


float pixel_match(float value, float target) {
	return 1.0 - step(0.5, abs(value - target));
}


// One authored source-pixel spine. Every horizontal change is only one pixel
// over two rows, so the line stays 8-connected without becoming a staircase
// ribbon or a black vertical rectangle.
float crack_path_offset(float local_row) {
	if (local_row < 2.0) {
		return -1.0;
	}
	if (local_row < 4.0) {
		return 0.0;
	}
	if (local_row < 6.0) {
		return 1.0;
	}
	if (local_row < 8.0) {
		return 0.0;
	}
	if (local_row < 10.0) {
		return -1.0;
	}
	if (local_row < 11.0) {
		return 0.0;
	}
	if (local_row < 13.0) {
		return 1.0;
	}
	return 2.0;
}


float fissure_growth(float local_row) {
	// The crack begins at the waterline/bottom edge and climbs upward in four
	// readable pixel groups. This keeps the impact origin grounded in the ice.
	float distance_from_bottom = 13.0 - local_row;
	float growth_segment = min(floor(distance_from_bottom / 3.5), 3.0);
	return step(growth_segment * 0.25 + 0.02, platform_break_amount);
}


float fissure_branch(float relative_column, float local_row) {
	// Three deliberately unequal branches. They touch the spine, but never
	// mirror one another or form the rejected radial/starburst crack.
	float upper_left = max(
		pixel_match(local_row, 4.0) * pixel_match(relative_column, 0.0),
		max(
			pixel_match(local_row, 3.0) * pixel_match(relative_column, -1.0),
			max(
				pixel_match(local_row, 2.0) * pixel_match(relative_column, -2.0),
				pixel_match(local_row, 2.0) * pixel_match(relative_column, -3.0))));
	float middle_right = max(
		pixel_match(local_row, 7.0) * pixel_match(relative_column, 1.0),
		max(
			pixel_match(local_row, 8.0) * pixel_match(relative_column, 2.0),
			max(
				pixel_match(local_row, 8.0) * pixel_match(relative_column, 3.0),
				pixel_match(local_row, 9.0) * pixel_match(relative_column, 4.0))));
	float lower_left = max(
		pixel_match(local_row, 10.0) * pixel_match(relative_column, -1.0),
		max(
			pixel_match(local_row, 11.0) * pixel_match(relative_column, -2.0),
			max(
				pixel_match(local_row, 11.0) * pixel_match(relative_column, -3.0),
				pixel_match(local_row, 12.0) * pixel_match(relative_column, -4.0))));
	return max(upper_left, max(middle_right, lower_left));
}


float fissure_glint(float relative_column, float local_row) {
	return max(
		pixel_match(local_row, 1.0) * pixel_match(relative_column, 0.0),
		max(
			pixel_match(local_row, 5.0) * pixel_match(relative_column, 2.0),
			max(
				pixel_match(local_row, 9.0) * pixel_match(relative_column, 0.0),
				pixel_match(local_row, 12.0) * pixel_match(relative_column, 2.0))));
}


void fragment() {
	vec4 source_surface = texture(TEXTURE, UV);
	vec4 source_down = texture(
			TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y));
	float source_row = floor(UV.y / TEXTURE_PIXEL_SIZE.y);
	float source_column = floor(UV.x / TEXTURE_PIXEL_SIZE.x);
	float source_width = 1.0 / TEXTURE_PIXEL_SIZE.x;
	float crack_local_row = source_row - crack_start_row;
	// Keep the reveal moving bottom-to-top, but vertically reverse the authored
	// silhouette as a separate operation so the crack itself points upward too.
	float authored_row = 13.0 - crack_local_row;
	float crack_relative_column = source_column - floor(source_width * 0.5);
	float crack_vertical = step(crack_start_row, source_row)
			* (1.0 - step(crack_end_row + 1.0, source_row));
	float crack_reveal = fissure_growth(crack_local_row);
	float vertical_fissure_core = crack_vertical * crack_reveal
			* pixel_match(
					crack_relative_column,
					crack_path_offset(authored_row));
	float branch_reveal = crack_vertical * crack_reveal
			* fissure_branch(crack_relative_column, authored_row);
	float glint_reveal = crack_vertical * crack_reveal
			* fissure_glint(crack_relative_column, authored_row);
	float ice_block = floor(source_column / max(ice_block_width, 1.0));
	float edge_step = step(0.72, stable_hash(ice_block))
			* edge_variation_rows;
	float visible_bottom_row = surface_bottom_row
			+ shallow_wall_rows + edge_step;
	float source_visible = 1.0 - step(visible_bottom_row, source_row);
	float source_down_visible = 1.0 - step(
			visible_bottom_row, source_row + 1.0);
	source_surface *= source_visible;
	source_down.a *= source_down_visible;

	float shallow_wall = step(surface_bottom_row, source_row)
			* source_visible * source_surface.a;
	float bottom_edge = source_surface.a * (1.0 - source_down.a);
	vec3 floating_ice = mix(
			source_surface.rgb, underside_tint.rgb,
			shallow_wall * underside_strength);
	floating_ice = mix(
			floating_ice, wet_edge_tint.rgb,
			bottom_edge * wet_edge_strength);
	float source_ice = step(0.03, source_surface.a);
	floating_ice = mix(
			floating_ice, crack_branch_color.rgb,
			branch_reveal * source_ice * 0.92);
	floating_ice = mix(
			floating_ice, crack_core_color.rgb,
			vertical_fissure_core * source_ice);
	floating_ice = mix(
			floating_ice, crack_glint_color.rgb,
			glint_reveal * source_ice * 0.72);
	COLOR = vec4(floating_ice, source_surface.a);
}
