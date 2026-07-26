shader_type canvas_item;

// Scene2 waterfall cloud motion.
// The opaque core stays fixed while a source-pixel-wide outer shell moves on
// quantized frames. This preserves the authored cloud mass and gives the
// surrounding wisps independent, pixel-stable breathing motion.

group_uniforms depth_grade;
uniform float saturation : hint_range(0.0, 1.25, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.25, 0.01) = 1.0;
uniform float brightness : hint_range(0.5, 1.25, 0.01) = 1.0;
uniform vec4 atmosphere_color : source_color = vec4(0.62, 0.73, 0.73, 1.0);
uniform float atmosphere_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform vec2 quiet_center = vec2(0.5);
uniform vec2 quiet_radius = vec2(0.2);
uniform float quiet_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 quiet_color : source_color = vec4(0.72, 0.76, 0.72, 1.0);
uniform float quiet_saturation : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float quiet_contrast : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float quiet_lift : hint_range(0.0, 0.2, 0.01) = 0.0;
group_uniforms;

group_uniforms pixel_motion;
uniform float motion_fps : hint_range(1.0, 12.0, 1.0) = 4.0;
uniform float cycle_sec : hint_range(4.0, 24.0, 0.5) = 12.0;
uniform float phase_offset : hint_range(0.0, 6.2832, 0.01) = 0.0;
uniform float sway_px : hint_range(-4.0, 4.0, 0.25) = 2.5;
uniform float bob_px : hint_range(0.0, 2.0, 0.25) = 1.0;
uniform float roll_px : hint_range(0.0, 2.0, 0.25) = 1.0;
uniform float roll_bands : hint_range(1.0, 6.0, 1.0) = 3.0;
uniform float edge_depth_px : hint_range(2.0, 20.0, 1.0) = 10.0;
uniform float core_alpha_threshold : hint_range(0.01, 0.95, 0.01) = 0.55;
group_uniforms;

float round_signed(float value) {
	return sign(value) * floor(abs(value) + 0.5);
}


float inside_uv(vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return inside.x * inside.y;
}


vec3 apply_depth_grade(vec3 input_col, vec2 mask_uv, vec2 texel_size) {
	float luma = dot(input_col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luma), input_col, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	graded *= brightness;
	graded = mix(graded, atmosphere_color.rgb, atmosphere_strength);

	vec2 pixel_uv = (
			floor(mask_uv / texel_size) + vec2(0.5)
	) * texel_size;
	vec2 quiet_delta = (
			pixel_uv - quiet_center
	) / max(quiet_radius, vec2(0.001));
	float quiet_mask = (
			1.0 - smoothstep(0.72, 1.0, length(quiet_delta))
	) * quiet_strength;
	float quiet_luma = dot(graded, vec3(0.299, 0.587, 0.114));
	vec3 quiet_col = mix(vec3(quiet_luma), graded, quiet_saturation);
	quiet_col = mix(quiet_color.rgb, quiet_col, quiet_contrast)
			+ vec3(quiet_lift);
	return mix(graded, quiet_col, quiet_mask);
}


void fragment() {
	float motion_time = floor(TIME * motion_fps) / motion_fps;
	float cycle = max(cycle_sec, 0.001);
	float phase = motion_time / cycle * TAU + phase_offset;

	// Broad y-dependent rolling prevents the edge from translating like one
	// cardboard cutout. Every offset is rounded back to a source texel.
	float roll_wave = sin(
			phase * 0.72 + UV.y * TAU * roll_bands + phase_offset * 0.37);
	float offset_x_px = round_signed(
			sin(phase) * sway_px + roll_wave * roll_px);
	float offset_y_px = round_signed(
			sin(phase * 2.0 + phase_offset * 0.53) * bob_px);
	vec2 moved_uv = UV - vec2(offset_x_px, offset_y_px) * TEXTURE_PIXEL_SIZE;
	vec2 moved_inside = step(vec2(0.0), moved_uv) * step(moved_uv, vec2(1.0));
	vec4 moved = texture(TEXTURE, clamp(moved_uv, vec2(0.0), vec2(1.0)))
			* moved_inside.x * moved_inside.y;
	vec4 base = texture(TEXTURE, UV);

	// A four-direction erosion test identifies the stable opaque core. Only the
	// surrounding shell follows moved_uv, so the cloud breathes without losing
	// its weight or exposing large holes behind the waterfall.
	vec2 shell = TEXTURE_PIXEL_SIZE * edge_depth_px;
	vec2 left_uv = UV - vec2(shell.x, 0.0);
	vec2 right_uv = UV + vec2(shell.x, 0.0);
	vec2 upper_uv = UV - vec2(0.0, shell.y);
	vec2 lower_uv = UV + vec2(0.0, shell.y);
	float left_alpha = texture(
			TEXTURE, clamp(left_uv, vec2(0.0), vec2(1.0))
	).a * inside_uv(left_uv);
	float right_alpha = texture(
			TEXTURE, clamp(right_uv, vec2(0.0), vec2(1.0))
	).a * inside_uv(right_uv);
	float upper_alpha = texture(
			TEXTURE, clamp(upper_uv, vec2(0.0), vec2(1.0))
	).a * inside_uv(upper_uv);
	float lower_alpha = texture(
			TEXTURE, clamp(lower_uv, vec2(0.0), vec2(1.0))
	).a * inside_uv(lower_uv);
	float stable_core_alpha = min(
			min(left_alpha, right_alpha),
			min(upper_alpha, lower_alpha));
	float stable_core = step(core_alpha_threshold, stable_core_alpha)
			* step(core_alpha_threshold, base.a);
	vec4 tex = mix(moved, base, stable_core);
	vec3 graded = apply_depth_grade(tex.rgb, UV, TEXTURE_PIXEL_SIZE);
	COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), tex.a) * COLOR;
}
