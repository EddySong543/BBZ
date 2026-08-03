shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float motion_time = 0.0;
uniform float motion_pixels : hint_range(0.0, 80.0, 0.1) = 28.0;
uniform float motion_period : hint_range(2.0, 12.0, 0.1) = 5.2;
uniform float bend_pixels : hint_range(0.0, 4.0, 0.1) = 1.5;
uniform float flow_contrast : hint_range(0.0, 0.3, 0.005) = 0.10;
uniform vec2 motion_direction = vec2(-1.0, 0.55);

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	vec2 along = normalize(motion_direction);
	vec2 across = vec2(-along.y, along.x);
	float clock = motion_time / max(motion_period, 0.001);

	// Two forward-only phases crossfade at their wrap points. Each phase
	// always advances toward the lower-left; neither phase reverses.
	float phase_a = fract(clock);
	float phase_b = fract(clock + 0.5);
	float phase_blend = abs(phase_a * 2.0 - 1.0);

	float spatial_phase = dot(UV, across) * TAU * 2.6;
	float bend_a = sin(
			spatial_phase - phase_a * TAU) * bend_pixels;
	float bend_b = sin(
			spatial_phase - phase_b * TAU) * bend_pixels;
	vec2 offset_a = (
			along * phase_a * motion_pixels
			+ across * bend_a);
	vec2 offset_b = (
			along * phase_b * motion_pixels
			+ across * bend_b);
	vec4 sample_a = texture(
			TEXTURE,
			UV - offset_a * TEXTURE_PIXEL_SIZE);
	vec4 sample_b = texture(
			TEXTURE,
			UV - offset_b * TEXTURE_PIXEL_SIZE);

	vec3 premultiplied_a = sample_a.rgb * sample_a.a;
	vec3 premultiplied_b = sample_b.rgb * sample_b.a;
	float mixed_alpha = mix(
			sample_a.a,
			sample_b.a,
			phase_blend);
	vec3 mixed_rgb = mix(
			premultiplied_a,
			premultiplied_b,
			phase_blend) / max(mixed_alpha, 0.001);

	float traveling_value = (
			0.5
			+ 0.5 * sin(
					dot(UV, along) * TAU * 3.2
					- clock * TAU));
	mixed_rgb *= (
			1.0
			+ (traveling_value - 0.35) * flow_contrast);
	COLOR = vec4(mixed_rgb, mixed_alpha) * vertex_color;
}
