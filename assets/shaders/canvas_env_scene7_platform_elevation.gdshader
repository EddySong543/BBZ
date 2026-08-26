shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 shadow_tint : source_color = vec4(0.42, 0.3, 0.4, 1.0);
uniform vec4 highlight_tint : source_color = vec4(0.93, 0.65, 0.58, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 0.72;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.04;
uniform float saturation : hint_range(0.0, 2.0) = 1.05;
uniform vec4 underside_tint : source_color = vec4(0.4, 0.267, 0.4, 1.0);
uniform float underside_strength : hint_range(0.0, 1.0) = 0.82;
uniform float surface_bottom_row : hint_range(0.0, 188.0) = 95.0;
uniform float shallow_wall_rows : hint_range(1.0, 8.0) = 4.0;
uniform float edge_variation_rows : hint_range(0.0, 2.0) = 1.0;


float stable_hash(float value) {
	return fract(sin(value * 12.9898) * 43758.5453);
}


void fragment() {
	vec4 source_surface = texture(TEXTURE, UV);
	vec4 source_down = texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y));
	float source_row = floor(UV.y / TEXTURE_PIXEL_SIZE.y);
	float source_column = floor(UV.x / TEXTURE_PIXEL_SIZE.x);
	float stone_block = floor(source_column / 7.0);
	float edge_step = step(0.72, stable_hash(stone_block))
			* edge_variation_rows;
	float visible_bottom_row = surface_bottom_row + shallow_wall_rows + edge_step;
	float source_visible = 1.0 - step(visible_bottom_row, source_row);
	float source_down_visible = 1.0 - step(visible_bottom_row, source_row + 1.0);
	source_surface *= source_visible;
	source_down.a *= source_down_visible;
	float luma = dot(source_surface.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 elevation_palette = mix(
		shadow_tint.rgb,
		highlight_tint.rgb,
		smoothstep(0.08, 0.88, luma));
	vec3 road = mix(source_surface.rgb, elevation_palette, grade_strength);
	float graded_luma = dot(road, vec3(0.2126, 0.7152, 0.0722));
	road = mix(vec3(graded_luma), road, saturation);
	road = (road - vec3(0.5)) * contrast + vec3(0.5);
	road *= brightness;

	// The authored walkable top stays intact. Only four to five source rows of
	// stone wall remain, so elevation reads as a shallow causeway instead of a
	// cliff. Water stays a separate layer; no water-colored shelf is generated.
	float bottom_edge = source_surface.a * (1.0 - source_down.a);
	vec3 source_neutral = vec3(luma) * vec3(0.96, 0.98, 0.88);
	vec3 underside = mix(source_neutral, underside_tint.rgb, 0.44);
	road = mix(road, underside, bottom_edge * underside_strength);
	COLOR = vec4(max(road, vec3(0.0)), source_surface.a);
}
