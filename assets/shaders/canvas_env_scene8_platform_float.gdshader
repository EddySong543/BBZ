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


float stable_hash(float value) {
	return fract(sin(value * 12.9898) * 43758.5453);
}


void fragment() {
	vec4 source_surface = texture(TEXTURE, UV);
	vec4 source_down = texture(
			TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y));
	float source_row = floor(UV.y / TEXTURE_PIXEL_SIZE.y);
	float source_column = floor(UV.x / TEXTURE_PIXEL_SIZE.x);
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
	COLOR = vec4(floating_ice, source_surface.a);
}
