shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 veil_color : source_color = vec4(0.34, 0.25, 0.17, 1.0);
uniform float motion_alpha : hint_range(0.0, 0.06, 0.001) = 0.028;
uniform float drift_speed : hint_range(0.0, 0.08, 0.002) = 0.034;
uniform float pixel_grid : hint_range(24.0, 120.0, 1.0) = 72.0;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 aspect_uv = vec2(UV.x * 1.7777778, UV.y);
	vec2 pixel_cell = floor(aspect_uv * pixel_grid);
	float time_phase = TIME * drift_speed;
	float broad_wave = sin((pixel_cell.x * 0.075) + (pixel_cell.y * 0.052) + time_phase);
	float cross_wave = sin((pixel_cell.x * -0.041) + (pixel_cell.y * 0.089) - time_phase * 0.73);
	float static_grain = hash21(pixel_cell);
	float field = clamp(0.5 + broad_wave * 0.22 + cross_wave * 0.16
			+ (static_grain - 0.5) * 0.08, 0.0, 1.0);
	vec2 centered = (UV - vec2(0.5)) * vec2(1.0, 0.76);
	float center_falloff = 1.0 - smoothstep(0.18, 0.78, length(centered));
	float alpha = motion_alpha * mix(0.38, 1.0, field) * mix(0.62, 1.0, center_falloff);
	COLOR = vec4(veil_color.rgb, alpha);
}
