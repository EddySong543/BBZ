shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint_color : source_color = vec4(1.0);
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.5, 0.01) = 1.0;
uniform float palette_steps : hint_range(8.0, 64.0, 1.0) = 32.0;
uniform float palette_remap_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 palette_shadow_color : source_color = vec4(0.32, 0.36, 0.36, 1.0);
uniform vec4 palette_mid_color : source_color = vec4(0.62, 0.66, 0.64, 1.0);
uniform vec4 palette_highlight_color : source_color = vec4(0.9, 0.92, 0.9, 1.0);
uniform bool hard_cut_enabled = false;
uniform float hard_cut_y : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float hard_cut_step_width_px : hint_range(2.0, 32.0, 1.0) = 12.0;
uniform bool source_trim_enabled = false;
uniform vec4 source_trim_rect_px = vec4(0.0);
uniform vec4 click_response_scene_rect = vec4(0.0, 0.0, 1.0, 1.0);

#include "res://assets/shaders/canvas_env_scene9_grass_click_response.gdshaderinc"

void fragment() {
	float response_scene_x = click_response_scene_rect.x
			+ UV.x * click_response_scene_rect.z;
	vec3 click_response = scene9_grass_click_response(response_scene_x);
	float response_grass_band = smoothstep(0.12, 0.28, UV.y)
			* (1.0 - smoothstep(0.78, 0.96, UV.y));
	vec2 response_uv = UV;
	response_uv.x -= click_response.x * click_displacement_px
			/ max(click_response_scene_rect.z, 1.0) * response_grass_band;
	response_uv.y -= click_response.y * click_displacement_px
			/ max(click_response_scene_rect.w, 1.0) * response_grass_band;
	vec4 tex = texture(TEXTURE, clamp(response_uv, vec2(0.0), vec2(1.0))) * COLOR;
	float visibility = 1.0;
	vec2 source_pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	if (hard_cut_enabled) {
		float step_group = mod(floor(source_pixel.x / hard_cut_step_width_px), 3.0) - 1.0;
		float connected_cut = hard_cut_y + step_group * TEXTURE_PIXEL_SIZE.y;
		visibility = step(connected_cut, UV.y);
	}
	if (source_trim_enabled) {
		float inside_x = step(source_trim_rect_px.x, source_pixel.x)
				* (1.0 - step(
						source_trim_rect_px.x + source_trim_rect_px.z,
						source_pixel.x));
		float inside_y = step(source_trim_rect_px.y, source_pixel.y)
				* (1.0 - step(
						source_trim_rect_px.y + source_trim_rect_px.w,
						source_pixel.y));
		visibility *= 1.0 - inside_x * inside_y;
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
	graded = mix(graded, click_highlight_color.rgb,
			click_response.z * click_highlight_strength * response_grass_band * tex.a);
	float steps = max(palette_steps - 1.0, 1.0);
	graded = floor(clamp(graded, vec3(0.0), vec3(1.0)) * steps + 0.5) / steps;

	COLOR = vec4(graded, tex.a * tint_color.a * visibility);
}
