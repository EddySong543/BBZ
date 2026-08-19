shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float motion_time = 0.0;
uniform float motion_pixels : hint_range(0.0, 80.0, 0.1) = 28.0;
uniform float motion_period : hint_range(2.0, 12.0, 0.1) = 5.2;
uniform float bend_pixels : hint_range(0.0, 4.0, 0.1) = 1.5;
uniform float flow_contrast : hint_range(0.0, 0.3, 0.005) = 0.10;
uniform vec2 motion_direction = vec2(-1.0, 0.55);
uniform vec3 palette_shadow = vec3(0.203922, 0.227451, 0.250980);
uniform vec3 palette_mid = vec3(0.349020, 0.388235, 0.431373);
uniform vec3 palette_light = vec3(0.666667, 0.705882, 0.745098);
uniform float palette_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D intro_path_texture : repeat_disable, filter_nearest;
uniform float intro_stroke_progress : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float intro_stroke_feather : hint_range(0.02, 0.24, 0.001) = 0.13;
uniform float intro_layer_offset : hint_range(-0.12, 0.12, 0.005) = 0.0;
uniform float intro_head_width : hint_range(0.02, 0.18, 0.001) = 0.075;
uniform float intro_head_strength : hint_range(0.0, 0.6, 0.01) = 0.30;

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
	float luminance = dot(
			mixed_rgb,
			vec3(0.299, 0.587, 0.114));
	vec3 graphite = mix(
			palette_shadow,
			palette_mid,
			smoothstep(0.08, 0.38, luminance));
	graphite = mix(
			graphite,
			palette_light,
			smoothstep(0.40, 0.76, luminance));
	mixed_rgb = mix(
			mixed_rgb,
			graphite,
			clamp(palette_strength, 0.0, 1.0));

	// The generated path follows clustered source brush marks. The broad
	// transition avoids the straight windshield-wiper edge of a UV sweep.
	float path_progress = texture(intro_path_texture, UV).r;
	float effective_progress = clamp(
			intro_stroke_progress + intro_layer_offset,
			0.0,
			1.0);
	float intro_reveal = (
			smoothstep(
					path_progress - intro_stroke_feather,
					path_progress,
					effective_progress));
	if (intro_stroke_progress <= 0.001) {
		intro_reveal = 0.0;
	} else if (intro_stroke_progress >= 0.999) {
		intro_reveal = 1.0;
	}
	float intro_head = (
			1.0
			- smoothstep(
					intro_head_width * 0.28,
					intro_head_width,
					abs(path_progress - effective_progress)));
	intro_head *= (
			intro_reveal
			* step(0.001, intro_stroke_progress)
			* (1.0 - step(0.999, intro_stroke_progress)));
	mixed_rgb = mix(
			mixed_rgb,
			palette_light,
			intro_head
				* clamp(intro_head_strength, 0.0, 0.6));
	COLOR = vec4(
			mixed_rgb,
			mixed_alpha * intro_reveal
		) * vertex_color;
}
