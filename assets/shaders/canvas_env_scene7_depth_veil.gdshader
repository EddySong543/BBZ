shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 mist_color : source_color = vec4(0.33, 0.52, 0.49, 1.0);
uniform vec4 dust_color : source_color = vec4(0.78, 0.67, 0.43, 1.0);
uniform float opacity : hint_range(0.0, 0.2) = 0.09;
uniform float top_fade : hint_range(0.02, 0.4) = 0.18;
uniform float bottom_fade : hint_range(0.02, 0.4) = 0.24;
uniform vec2 pixel_grid = vec2(480.0, 96.0);
uniform float drift_speed : hint_range(0.0, 0.5) = 0.16;
uniform float drift_phase = 0.0;

float block_noise(vec2 block) {
	return fract(sin(dot(block, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_block_noise(vec2 point) {
	vec2 base = floor(point);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(point));
	float top = mix(
		block_noise(base),
		block_noise(base + vec2(1.0, 0.0)),
		blend.x);
	float bottom = mix(
		block_noise(base + vec2(0.0, 1.0)),
		block_noise(base + vec2(1.0, 1.0)),
		blend.x);
	return mix(top, bottom, blend.y);
}

void fragment() {
	vec2 pixel_uv = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	vec2 broad_point = pixel_uv * vec2(52.0, 12.0)
			+ vec2(TIME * drift_speed + drift_phase, 0.0);
	float broad = smooth_block_noise(broad_point);
	float detail = smooth_block_noise(
			pixel_uv * vec2(127.0, 31.0)
			+ vec2(-TIME * drift_speed * 0.37 + drift_phase * 1.7, 0.0));
	float broken_shape = smoothstep(0.24, 0.72, broad * 0.72 + detail * 0.28);
	float vertical_band = smoothstep(0.0, top_fade, pixel_uv.y)
			* (1.0 - smoothstep(1.0 - bottom_fade, 1.0, pixel_uv.y));
	float warm_mix = clamp(pixel_uv.y * 0.62 + broad * 0.28, 0.0, 1.0);
	vec3 veil_color = mix(mist_color.rgb, dust_color.rgb, warm_mix);
	float alpha = opacity * vertical_band * mix(0.38, 1.0, broken_shape);
	COLOR = vec4(veil_color, alpha);
}
