shader_type canvas_item;

// Scene9 distant silver-grass wind. It uses the same subdivided-mesh vertex
// method as Scene5's wheat: the root plane stays fixed while the visible upper
// mass bends in a shared world-space gust. Texture sampling itself never warps.

group_uniforms wind_geometry;
uniform float geometry_y_start : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float geometry_y_feather : hint_range(0.0, 0.2, 0.01) = 0.04;
uniform float root_y : hint_range(0.7, 1.0, 0.01) = 0.98;
uniform float bend_power : hint_range(0.5, 3.0, 0.05) = 1.65;
uniform float cycle_sec : hint_range(4.0, 20.0, 0.1) = 11.6;
uniform float sway_px : hint_range(0.0, 5.0, 0.1) = 1.8;
uniform float detail_px : hint_range(0.0, 2.0, 0.05) = 0.35;
uniform float gust_lift_px : hint_range(0.0, 2.0, 0.05) = 0.75;
uniform float gust_cycle_sec : hint_range(3.0, 16.0, 0.1) = 7.8;
uniform float phase_seed : hint_range(0.0, 12.0, 0.1) = 4.2;
group_uniforms;

#include "res://assets/shaders/canvas_env_scene9_grass_click_response.gdshaderinc"

group_uniforms field_light;
uniform float field_wave_strength : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float field_wave_speed : hint_range(0.0, 0.1, 0.001) = 0.022;
uniform vec4 field_wave_color : source_color = vec4(0.86, 0.94, 0.92, 1.0);
group_uniforms;

group_uniforms depth_grade;
uniform vec4 tint_color : source_color = vec4(0.9, 0.98, 0.95, 1.0);
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 0.98;
uniform float saturation : hint_range(0.0, 2.0, 0.01) = 0.55;
uniform float contrast : hint_range(0.0, 2.0, 0.01) = 0.9;
uniform float palette_steps : hint_range(4.0, 64.0, 1.0) = 24.0;
uniform float palette_remap_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 palette_shadow_color : source_color = vec4(0.4, 0.44, 0.44, 1.0);
uniform vec4 palette_mid_color : source_color = vec4(0.72, 0.74, 0.72, 1.0);
uniform vec4 palette_highlight_color : source_color = vec4(0.96, 0.97, 0.95, 1.0);
uniform float ground_harmony_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float ground_harmony_start : hint_range(0.0, 1.0, 0.01) = 0.62;
uniform vec4 ground_harmony_color : source_color = vec4(0.55, 0.58, 0.51, 1.0);
group_uniforms;

group_uniforms source_trim;
uniform bool source_trim_enabled = false;
// Source-pixel rectangle: x, y, width, height. The hard cut remains aligned
// with the authored pixel grid even while the subdivided mesh bends.
uniform vec4 source_trim_rect_px = vec4(0.0);
group_uniforms;

void vertex() {
	float active = smoothstep(
			geometry_y_start - geometry_y_feather,
			geometry_y_start + geometry_y_feather,
			UV.y);
	float height_ratio = clamp(
			(root_y - UV.y) / max(root_y - geometry_y_start, 0.001),
			0.0, 1.0);
	float root_pin = 1.0 - smoothstep(root_y - 0.09, root_y, UV.y);
	float bend_weight = pow(height_ratio, bend_power) * active * root_pin;
	float world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
	float phase = TIME * TAU / max(cycle_sec, 0.001)
			+ world_x * 0.012 + phase_seed;
	float main_bend = sin(phase);
	float lagging_bend = sin(phase * 0.58 - 0.85);
	float detail = sin(phase * 2.15 + UV.y * TAU * 1.7);
	float offset_px = sway_px * (main_bend * 0.72 + lagging_bend * 0.36)
			+ detail_px * detail;
	float gust_phase = TIME * TAU / max(gust_cycle_sec, 0.001)
			- world_x * 0.018 + phase_seed * 0.61;
	float gust_front = smoothstep(0.28, 0.86, sin(gust_phase) * 0.5 + 0.5);
	float lift_px = gust_lift_px * (gust_front * 0.82
			+ (sin(gust_phase * 1.7 + UV.x * TAU) * 0.5 + 0.5) * 0.18);
	vec3 click_response = scene9_grass_click_response(world_x);
	VERTEX.x += offset_px * bend_weight;
	VERTEX.y -= lift_px * bend_weight;
	VERTEX.x += click_response.x * click_displacement_px * bend_weight;
	VERTEX.y += click_response.y * click_displacement_px * bend_weight;
	COLOR.rgb = mix(COLOR.rgb, click_highlight_color.rgb,
			click_response.z * click_highlight_strength * bend_weight);
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV) * COLOR;
	if (source_trim_enabled) {
		vec2 source_pixel = floor(UV / TEXTURE_PIXEL_SIZE);
		float inside_x = step(source_trim_rect_px.x, source_pixel.x)
				* (1.0 - step(
						source_trim_rect_px.x + source_trim_rect_px.z,
						source_pixel.x));
		float inside_y = step(source_trim_rect_px.y, source_pixel.y)
				* (1.0 - step(
						source_trim_rect_px.y + source_trim_rect_px.w,
						source_pixel.y));
		texel.a *= 1.0 - inside_x * inside_y;
	}
	float luma = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luma), texel.rgb, saturation);
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
	float wave_center = fract(TIME * field_wave_speed + 0.18);
	float wave_distance = abs(fract(UV.x - wave_center + 0.5) - 0.5);
	float wave = 1.0 - smoothstep(0.07, 0.16, wave_distance);
	float grass_band = smoothstep(0.22, 0.38, UV.y)
			* (1.0 - smoothstep(0.72, 0.9, UV.y));
	graded = mix(graded, field_wave_color.rgb,
			wave * grass_band * field_wave_strength * texel.a);
	float ground_harmony = smoothstep(
			ground_harmony_start, 1.0, UV.y) * ground_harmony_strength;
	vec3 grounded_color = ground_harmony_color.rgb
			* mix(0.72, 1.08, clamp(luma, 0.0, 1.0));
	graded = mix(graded, grounded_color, ground_harmony);
	graded = floor(clamp(graded, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)) / palette_steps;
	COLOR = vec4(graded, texel.a);
}
