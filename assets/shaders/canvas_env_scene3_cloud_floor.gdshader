shader_type canvas_item;
render_mode unshaded, blend_mix;

// Opaque underpaint for the moving cloud sea. The animated cloud silhouettes
// remain above it, while this layer guarantees that Sky never leaks through
// the lower viewport boundary.
uniform vec4 shadow_color : source_color = vec4(0.31, 0.42, 0.44, 1.0);
uniform vec4 mid_color : source_color = vec4(0.43, 0.55, 0.56, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.62, 0.70, 0.68, 1.0);
uniform float top_alpha : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float bottom_alpha : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float opaque_start : hint_range(0.2, 0.9, 0.01) = 0.58;
uniform float flow_speed : hint_range(-0.05, 0.05, 0.001) = -0.004;
uniform float band_strength : hint_range(0.0, 0.3, 0.01) = 0.10;
uniform vec2 pixel_grid = vec2(480.0, 270.0);


float hash11(float value) {
	return fract(sin(value * 91.3458) * 47453.5453);
}


void fragment() {
	vec2 pixel_uv = (floor(SCREEN_UV * pixel_grid) + vec2(0.5))
			/ pixel_grid;
	float flowed_x = pixel_uv.x + TIME * flow_speed;
	float broad = sin(flowed_x * 15.0 + pixel_uv.y * 5.0);
	float fine = sin(flowed_x * 31.0 - pixel_uv.y * 9.0 + 1.7);
	float row = floor(pixel_uv.y * 54.0);
	float broken_band = (hash11(row) - 0.5) * 0.32;
	float cloud_value = clamp(
			0.52 + broad * 0.18 + fine * 0.07 + broken_band,
			0.0,
			1.0);
	cloud_value = floor(cloud_value * 5.0 + 0.5) / 5.0;

	vec3 cloud_color = mix(shadow_color.rgb, mid_color.rgb, cloud_value);
	float soft_highlight = smoothstep(0.58, 0.94, cloud_value);
	cloud_color = mix(
			cloud_color,
			highlight_color.rgb,
			soft_highlight * band_strength);

	float coverage = smoothstep(0.0, opaque_start, UV.y);
	float alpha = mix(top_alpha, bottom_alpha, coverage);
	COLOR = vec4(clamp(cloud_color, vec3(0.0), vec3(1.0)), alpha);
}
