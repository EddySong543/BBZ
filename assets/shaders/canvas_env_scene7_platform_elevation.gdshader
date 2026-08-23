shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 shadow_tint : source_color = vec4(0.16, 0.31, 0.28, 1.0);
uniform vec4 highlight_tint : source_color = vec4(0.91, 0.73, 0.43, 1.0);
uniform vec4 dry_edge_color : source_color = vec4(1.0, 0.86, 0.58, 1.0);
uniform vec4 wet_edge_color : source_color = vec4(0.12, 0.34, 0.32, 1.0);
uniform vec4 waterline_color : source_color = vec4(0.58, 0.88, 0.76, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 0.22;
uniform float brightness : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.0, 2.0) = 1.08;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float dry_edge_strength : hint_range(0.0, 1.0) = 0.34;
uniform float wet_edge_strength : hint_range(0.0, 1.0) = 0.42;
uniform float contact_shadow_strength : hint_range(0.0, 1.0) = 0.5;
uniform float waterline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float contact_band_px : hint_range(5.0, 10.0) = 7.0;
uniform float screen_px_per_texel : hint_range(1.0, 12.0) = 5.75;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float edge_texels = clamp(contact_band_px / screen_px_per_texel, 1.0, 2.0);
	float alpha_above = texture(TEXTURE, UV - vec2(0.0, texel.y)).a;
	float alpha_below = texture(TEXTURE, UV + vec2(0.0, texel.y)).a;
	float alpha_up_contact = max(
		texture(TEXTURE, UV - vec2(0.0, texel.y * edge_texels)).a,
		texture(TEXTURE, UV - vec2(0.0, texel.y * 2.0)).a);

	float top_inside = source.a * (1.0 - alpha_above);
	float bottom_inside = source.a * (1.0 - alpha_below);
	float outside_below = (1.0 - source.a) * alpha_up_contact;

	float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 elevation_palette = mix(
		shadow_tint.rgb,
		highlight_tint.rgb,
		smoothstep(0.08, 0.88, luma));
	vec3 road = mix(source.rgb, elevation_palette, grade_strength);
	float graded_luma = dot(road, vec3(0.2126, 0.7152, 0.0722));
	road = mix(vec3(graded_luma), road, saturation);
	road = (road - vec3(0.5)) * contrast + vec3(0.5);
	road *= brightness;
	road = mix(road, dry_edge_color.rgb, top_inside * dry_edge_strength);
	road = mix(road, wet_edge_color.rgb, bottom_inside * wet_edge_strength);

	float source_x = floor(UV.x / texel.x);
	float broken_line = step(0.78,
		sin(source_x * 0.61 + floor(source_x / 11.0) * 1.3) * 0.5 + 0.5);
	float waterline = outside_below * broken_line * waterline_strength;
	float contact_shadow = outside_below * contact_shadow_strength;
	vec3 outside_color = mix(wet_edge_color.rgb, waterline_color.rgb, waterline);
	float outside_alpha = max(contact_shadow * 0.72, waterline);

	vec3 output_color = mix(outside_color, road, source.a);
	float output_alpha = max(source.a, outside_alpha);
	COLOR = vec4(max(output_color, vec3(0.0)), output_alpha);
}
