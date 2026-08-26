shader_type canvas_item;
render_mode unshaded, blend_mix;

// Palette-constrained reflections for the rear spring. The screen copy is
// made after the three midground banks have drawn, then this polygon mirrors
// only green/cyan vegetation signals into the exact rear-water silhouette.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms layout;
uniform vec2 screen_px = vec2(1920.0, 1080.0);
uniform float water_depth_px : hint_range(60.0, 100.0) = 80.0;
uniform float reflection_height_px : hint_range(64.0, 128.0) = 96.0;
uniform float sample_gap_px : hint_range(0.0, 8.0) = 2.0;
uniform float slice_px : hint_range(1.0, 6.0) = 3.0;
uniform float breakup_width_px : hint_range(24.0, 96.0) = 52.0;
uniform float breakup_offset_px : hint_range(0.0, 8.0) = 4.0;
group_uniforms;

group_uniforms palette;
uniform vec4 surface_color : source_color = vec4(0.133, 0.667, 0.6, 1.0);
uniform vec4 mid_color : source_color = vec4(0.133, 0.533, 0.533, 1.0);
uniform vec4 deep_color : source_color = vec4(0.067, 0.267, 0.4, 1.0);
uniform vec4 spring_glow_color : source_color = vec4(0.44, 0.88, 0.72, 1.0);
uniform float reflection_strength : hint_range(0.0, 0.6) = 0.30;
uniform float reflection_colorize : hint_range(0.0, 1.0) = 0.88;
uniform float vegetation_floor : hint_range(0.0, 1.0) = 0.18;
group_uniforms;

group_uniforms motion;
uniform float anim_fps : hint_range(1.0, 12.0) = 8.0;
uniform float reflection_period_sec : hint_range(4.0, 16.0) = 9.8;
uniform float reflection_sway_px : hint_range(0.0, 8.0) = 3.0;
uniform float reflection_breathe_strength : hint_range(0.0, 0.4) = 0.16;
uniform float diagnostic_time_sec = -1.0;
group_uniforms;

varying float shoreline_depth;


float hash21(vec2 p) {
	p = mod(p, vec2(509.0, 251.0));
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float motion_time() {
	return diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
}


float signed_pixel_snap(float value, float step_size) {
	float magnitude = floor(abs(value) / step_size + 0.5) * step_size;
	return sign(value) * magnitude;
}


vec3 palette_reflection_from_luma(float luma) {
	vec3 reflected = mix(
			deep_color.rgb,
			mid_color.rgb,
			smoothstep(0.04, 0.42, luma));
	reflected = mix(
			reflected,
			surface_color.rgb,
			smoothstep(0.34, 0.72, luma));
	reflected = mix(
			reflected,
			spring_glow_color.rgb,
			smoothstep(0.70, 0.94, luma));
	return reflected;
}


float vegetation_signal(vec3 source, float luma) {
	float green_cyan = max(
			source.g - source.r * 0.86,
			source.b - source.r * 0.96);
	float chroma_signal = smoothstep(0.025, 0.22, green_cyan);
	float dark_canopy = (1.0 - smoothstep(0.32, 0.62, luma))
			* smoothstep(-0.025, 0.085, source.g - source.r);
	float biolume_signal = smoothstep(0.46, 0.82, luma)
			* smoothstep(0.02, 0.13, green_cyan);
	return clamp(max(chroma_signal, max(dark_canopy * 0.78,
			biolume_signal)), 0.0, 1.0);
}


void vertex() {
	shoreline_depth = COLOR.r;
}


void fragment() {
	float t = floor(motion_time() * anim_fps) / anim_fps;
	float depth = clamp(shoreline_depth, 0.0, 1.0);
	float depth_px = floor(depth * water_depth_px / slice_px) * slice_px;
	float slice_id = floor(depth_px / slice_px);
	float x_px = SCREEN_UV.x * screen_px.x;
	float x_cell = floor(x_px / breakup_width_px);
	float slice_noise = hash21(vec2(x_cell, slice_id + 41.0));
	float static_offset = (floor(slice_noise * 3.0) - 1.0)
			* breakup_offset_px;
	float motion_phase = t * TAU / max(reflection_period_sec, 0.001)
			+ slice_id * 0.71 + slice_noise * TAU;
	float animated_offset = signed_pixel_snap(
			sin(motion_phase) * reflection_sway_px, 1.0);
	float x_offset = static_offset + animated_offset;

	// Recover the current moving shoreline from this fragment and the authored
	// depth mask, then sample an increasingly high point above that shoreline.
	float screen_y_px = SCREEN_UV.y * screen_px.y;
	float shoreline_y_px = screen_y_px - depth * water_depth_px;
	float source_y_px = shoreline_y_px - sample_gap_px
			- depth * reflection_height_px;
	vec2 sample_uv = clamp(
			vec2((x_px + x_offset) / screen_px.x,
				source_y_px / screen_px.y),
			vec2(0.0), vec2(1.0));
	vec3 source = textureLod(screen_tex, sample_uv, 0.0).rgb;
	float luma = dot(source, vec3(0.2126, 0.7152, 0.0722));
	float plant_mask = max(vegetation_signal(source, luma), vegetation_floor);

	vec3 palette_color = palette_reflection_from_luma(luma);
	vec3 reflected = mix(source, palette_color, reflection_colorize);
	reflected = floor(clamp(reflected, vec3(0.0), vec3(1.0))
			* 31.0 + 0.5) / 31.0;

	float enter_water = smoothstep(0.035, 0.13, depth);
	float fade_before_platform = 1.0 - smoothstep(0.62, 0.96, depth);
	float broken_alpha = mix(0.72, 1.0, slice_noise);
	float breathe = floor(
			(0.5 + 0.5 * sin(motion_phase + 0.83)) * 3.0 + 0.5) / 3.0;
	broken_alpha *= mix(
			1.0 - reflection_breathe_strength, 1.0, breathe);
	float alpha = reflection_strength * plant_mask * enter_water
			* fade_before_platform * broken_alpha;
	COLOR = vec4(reflected, alpha);
}
