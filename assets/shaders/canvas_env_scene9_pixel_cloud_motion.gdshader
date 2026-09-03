shader_type canvas_item;
render_mode unshaded, blend_mix;

// Scene9-only GPU reconstruction of the accepted cloud remap. The immutable
// base texture and metadata are sampled on their authored 592x136 pixel grid;
// no runtime Image rebuild or texture upload occurs after scene setup.
uniform sampler2D metadata_texture : filter_nearest, repeat_disable;
uniform sampler2D cloud_texture : filter_nearest, repeat_disable;
uniform vec2 source_pixel_size = vec2(0.00168918919, 0.00735294118);
uniform float source_phase = 0.0;
uniform float impact_source_x_px = 365.0;
uniform float maximum_horizontal_displacement_px = 3.0;
uniform float maximum_vertical_displacement_px = 3.0;
uniform float bottom_lock_depth_px = 8.0;
uniform float motion_blend_depth_px = 16.0;
// xyz = center x/y + normalized ripple_phase, w = active. Three independent slots let
// repeated clicks form concurrent rings instead of restarting one global wave.
uniform vec4 ripple_wave_0 = vec4(0.0);
uniform vec4 ripple_wave_1 = vec4(0.0);
uniform vec4 ripple_wave_2 = vec4(0.0);

uniform vec4 tint_color : source_color = vec4(1.0);
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.5, 0.01) = 1.0;
uniform float palette_steps : hint_range(8.0, 64.0, 1.0) = 32.0;
uniform float palette_remap_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 palette_shadow_color : source_color = vec4(0.32, 0.36, 0.36, 1.0);
uniform vec4 palette_mid_color : source_color = vec4(0.62, 0.66, 0.64, 1.0);
uniform vec4 palette_highlight_color : source_color = vec4(0.9, 0.92, 0.9, 1.0);

float smootherstep(float value) {
	float t = clamp(value, 0.0, 1.0);
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float ripple_envelope(float phase) {
	if (phase <= 0.24) {
		return smootherstep(phase / 0.24);
	}
	return 1.0 - smootherstep((phase - 0.24) / 0.76);
}

vec4 metadata_at(vec2 pixel) {
	vec2 canvas_size = 1.0 / source_pixel_size;
	vec2 clamped_pixel = clamp(pixel, vec2(0.0), canvas_size - vec2(1.0));
	return texture(metadata_texture,
			(clamped_pixel + vec2(0.5)) * source_pixel_size);
}

vec2 motion_source_pixel(vec2 destination_pixel) {
	vec4 metadata = metadata_at(destination_pixel);
	if (metadata.a < 0.5) {
		return vec2(-1.0);
	}
	float bottom_y = floor(metadata.g * 255.0 + 0.5) - 1.0;
	float distance_from_bottom = bottom_y - destination_pixel.y;
	if (distance_from_bottom < bottom_lock_depth_px) {
		return destination_pixel;
	}
	float motion_weight = clamp(
			(distance_from_bottom - bottom_lock_depth_px + 1.0)
			/ max(motion_blend_depth_px, 0.001), 0.0, 1.0);
	float interior_weight = metadata.r;
	float radial_distance = abs(destination_pixel.x - impact_source_x_px);
	float phase = mod(radial_distance - source_phase, 48.0);
	float outward_wave = 0.5 + 0.5 * sin(6.28318530718 * phase / 48.0);
	float vertical_wave = sin(
			6.28318530718 * (phase + 12.0) / 48.0);
	float horizontal_shift = round(outward_wave
			* maximum_horizontal_displacement_px
			* motion_weight * interior_weight);
	float vertical_shift = round(vertical_wave
			* maximum_vertical_displacement_px * motion_weight);
	float direction = destination_pixel.x < impact_source_x_px ? -1.0 : 1.0;
	vec2 source_pixel = destination_pixel
			- vec2(direction * horizontal_shift, vertical_shift);
	if (source_pixel.x < 92.0 || source_pixel.x >= 500.0
			|| source_pixel.y < 0.0 || source_pixel.y >= 136.0) {
		return vec2(-1.0);
	}
	return source_pixel;
}

vec4 sample_authored_pixel(vec2 source_pixel) {
	if (source_pixel.x < 0.0) {
		return vec4(0.0);
	}
	return texture(cloud_texture,
			(source_pixel + vec2(0.5)) * source_pixel_size);
}

float ring_band(float distance_value, float radius, float strength) {
	if (radius <= 0.0) {
		return 0.0;
	}
	return (1.0 - clamp(abs(distance_value - radius) / 2.6, 0.0, 1.0))
			* strength;
}

vec2 ripple_pixel_offset(vec2 destination_pixel, vec4 wave) {
	if (wave.w < 0.5) {
		return vec2(0.0);
	}
	vec2 delta = destination_pixel - wave.xy;
	float distance_value = length(delta);
	if (distance_value <= 0.001) {
		return vec2(0.0);
	}
	float phase = wave.z;
	float leading_radius = mix(2.0, 22.0,
			1.0 - pow(1.0 - phase, 2.0));
	float ring_weight = max(
			ring_band(distance_value, leading_radius, 1.0),
			max(ring_band(distance_value, leading_radius - 7.0, 0.78),
				ring_band(distance_value, leading_radius - 14.0, 0.56)));
	float displacement = round(2.0 * ring_weight * ripple_envelope(phase));
	return round(delta / distance_value * displacement);
}

void fragment() {
	vec2 destination_pixel = floor(UV / source_pixel_size);
	vec2 animated_source = motion_source_pixel(destination_pixel);
	vec4 tex = sample_authored_pixel(animated_source);

	vec4 destination_metadata = metadata_at(destination_pixel);
	float bottom_y = floor(destination_metadata.g * 255.0 + 0.5) - 1.0;
	float distance_from_bottom = bottom_y - destination_pixel.y;
	if (tex.a > 0.0 && destination_metadata.r > 0.0
			&& distance_from_bottom >= bottom_lock_depth_px) {
		vec2 ripple_offset = ripple_pixel_offset(destination_pixel, ripple_wave_0)
				+ ripple_pixel_offset(destination_pixel, ripple_wave_1)
				+ ripple_pixel_offset(destination_pixel, ripple_wave_2);
		ripple_offset = clamp(ripple_offset, vec2(-3.0), vec2(3.0));
		if (length(ripple_offset) > 0.001) {
			vec2 ripple_source = destination_pixel
					- ripple_offset;
			vec4 ripple_tex = sample_authored_pixel(
					motion_source_pixel(ripple_source));
			if (ripple_tex.a > 0.0) {
				tex = ripple_tex;
			}
		}
	}

	float luma = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luma), tex.rgb, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	graded *= tint_color.rgb * brightness;
	vec3 shadow_to_mid = mix(
			palette_shadow_color.rgb,
			palette_mid_color.rgb,
			smoothstep(0.08, 0.58, luma));
	vec3 palette_color = mix(
			shadow_to_mid,
			palette_highlight_color.rgb,
			smoothstep(0.52, 0.94, luma));
	graded = mix(graded, palette_color, palette_remap_strength);
	float steps = max(palette_steps - 1.0, 1.0);
	graded = floor(clamp(graded, vec3(0.0), vec3(1.0))
			* steps + 0.5) / steps;
	COLOR = vec4(graded, tex.a * tint_color.a * COLOR.a);
}
