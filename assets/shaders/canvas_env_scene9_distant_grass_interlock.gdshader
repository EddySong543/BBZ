shader_type canvas_item;

group_uniforms wind_geometry;
uniform float geometry_y_start : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float geometry_y_feather : hint_range(0.0, 0.2, 0.01) = 0.04;
uniform float root_y : hint_range(0.7, 1.0, 0.01) = 0.98;
uniform float bend_power : hint_range(0.5, 3.0, 0.05) = 1.65;
uniform float cycle_sec : hint_range(4.0, 20.0, 0.1) = 10.6;
uniform float sway_px : hint_range(0.0, 5.0, 0.1) = 2.6;
uniform float detail_px : hint_range(0.0, 2.0, 0.05) = 0.55;
uniform float gust_lift_px : hint_range(0.0, 2.0, 0.05) = 0.75;
uniform float gust_cycle_sec : hint_range(3.0, 16.0, 0.1) = 7.8;
uniform float phase_seed : hint_range(0.0, 12.0, 0.1) = 4.2;
group_uniforms;

#include "res://assets/shaders/canvas_env_scene9_grass_click_response.gdshaderinc"

group_uniforms field_light;
uniform float field_wave_strength : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform float field_wave_speed : hint_range(0.0, 0.1, 0.001) = 0.028;
uniform vec4 field_wave_color : source_color = vec4(0.93, 0.96, 0.96, 1.0);
group_uniforms;

group_uniforms depth_grade;
uniform vec4 tint_color : source_color = vec4(0.98, 0.99, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.02;
uniform float saturation : hint_range(0.0, 2.0, 0.01) = 0.72;
uniform float contrast : hint_range(0.0, 2.0, 0.01) = 0.94;
uniform float palette_steps : hint_range(4.0, 64.0, 1.0) = 20.0;
uniform float palette_remap_strength : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform vec4 palette_shadow_color : source_color = vec4(0.61, 0.71, 0.83, 1.0);
uniform vec4 palette_mid_color : source_color = vec4(0.77, 0.83, 0.99, 1.0);
uniform vec4 palette_highlight_color : source_color = vec4(0.93, 0.96, 0.96, 1.0);
uniform float ground_harmony_strength : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform float ground_harmony_start : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform vec4 ground_harmony_color : source_color = vec4(0.33, 0.42, 0.52, 1.0);
group_uniforms;

group_uniforms source_trim;
uniform bool source_trim_enabled = true;
uniform vec4 source_trim_rect_px = vec4(0.0, 0.0, 109.0, 80.0);
group_uniforms;

group_uniforms contact_interlock;
uniform bool contact_enabled = false;
uniform sampler2D contact_platform_texture;
uniform vec4 self_scene_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 contact_platform_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 contact_platform_texel_size = vec2(0.00245098, 0.00735294);
uniform vec2 contact_cluster_size = vec2(18.0, 12.0);
uniform bool contact_shadow_enabled = false;
uniform vec4 contact_shadow_color : source_color = vec4(0.18, 0.25, 0.31, 1.0);
uniform float contact_shadow_strength : hint_range(0.0, 0.5, 0.01) = 0.18;
uniform float contact_shadow_radius_px : hint_range(2.0, 24.0, 1.0) = 10.0;
uniform vec2 contact_shadow_offset_px = vec2(0.0);
group_uniforms;


float inside_scene_rect(vec2 scene_position, vec4 scene_rect) {
	vec2 minimum = step(scene_rect.xy, scene_position);
	vec2 maximum = step(scene_position, scene_rect.xy + scene_rect.zw);
	return minimum.x * minimum.y * maximum.x * maximum.y;
}


float sample_layer_alpha(vec4 scene_rect, vec2 scene_position) {
	vec2 layer_uv = (scene_position - scene_rect.xy) / max(scene_rect.zw, vec2(0.001));
	return texture(contact_platform_texture, clamp(layer_uv, vec2(0.0), vec2(1.0))).a
			* inside_scene_rect(scene_position, scene_rect);
}


float surface_band(
		float alpha_here,
		float alpha_above_one,
		float alpha_above_two,
		float alpha_above_three) {
	float open_above = max(
			1.0 - alpha_above_one,
			max(1.0 - alpha_above_two, 1.0 - alpha_above_three));
	return step(0.5, alpha_here) * step(0.5, open_above);
}


float interlock_cluster(vec2 scene_position) {
	vec2 cell = floor(scene_position / max(contact_cluster_size, vec2(1.0)));
	float cluster_id = mod(cell.x * 2.0 + cell.y * 3.0 + mod(cell.x, 3.0), 7.0);
	return 1.0 - step(3.0, cluster_id);
}


float platform_surface_at(vec2 scene_position) {
	vec2 platform_uv = (scene_position - contact_platform_rect.xy)
			/ max(contact_platform_rect.zw, vec2(0.001));
	vec2 safe_uv = clamp(platform_uv, vec2(0.0), vec2(1.0));
	float surface = surface_band(
			texture(contact_platform_texture, safe_uv).a,
			texture(contact_platform_texture,
					safe_uv - vec2(0.0, contact_platform_texel_size.y)).a,
			texture(contact_platform_texture,
					safe_uv - vec2(0.0, contact_platform_texel_size.y * 2.0)).a,
			texture(contact_platform_texture,
					safe_uv - vec2(0.0, contact_platform_texel_size.y * 3.0)).a);
	return surface * inside_scene_rect(scene_position, contact_platform_rect);
}


float soft_contact_alpha(vec2 scene_position) {
	float radius = contact_shadow_radius_px;
	vec2 origin = scene_position - contact_shadow_offset_px;
	float result = platform_surface_at(origin) * 4.0;
	result += platform_surface_at(origin + vec2(radius, 0.0)) * 2.0;
	result += platform_surface_at(origin - vec2(radius, 0.0)) * 2.0;
	result += platform_surface_at(origin + vec2(0.0, radius)) * 2.0;
	result += platform_surface_at(origin - vec2(0.0, radius)) * 2.0;
	result += platform_surface_at(origin + vec2(radius, radius));
	result += platform_surface_at(origin + vec2(radius, -radius));
	result += platform_surface_at(origin + vec2(-radius, radius));
	result += platform_surface_at(origin - vec2(radius, radius));
	return result / 16.0;
}


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
	float visibility = 1.0;
	float contact_shadow = 0.0;
	vec2 source_pixel = floor(UV / TEXTURE_PIXEL_SIZE);
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
	if (contact_enabled || contact_shadow_enabled) {
		vec2 scene_position = self_scene_rect.xy + UV * self_scene_rect.zw;
		vec2 platform_uv = (scene_position - contact_platform_rect.xy)
				/ max(contact_platform_rect.zw, vec2(0.001));
		float platform_alpha = sample_layer_alpha(contact_platform_rect, scene_position);
		vec2 safe_platform_uv = clamp(platform_uv, vec2(0.0), vec2(1.0));
		float platform_surface = surface_band(
				texture(contact_platform_texture, safe_platform_uv).a,
				texture(contact_platform_texture, safe_platform_uv
						- vec2(0.0, contact_platform_texel_size.y)).a,
				texture(contact_platform_texture, safe_platform_uv
						- vec2(0.0, contact_platform_texel_size.y * 2.0)).a,
				texture(contact_platform_texture, safe_platform_uv
						- vec2(0.0, contact_platform_texel_size.y * 3.0)).a);
		if (contact_enabled) {
			float platform_claim = 1.0 - interlock_cluster(scene_position);
			visibility *= 1.0 - step(0.5, platform_alpha)
					* platform_surface * platform_claim;
		}
		if (contact_shadow_enabled) {
			contact_shadow = soft_contact_alpha(scene_position);
		}
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
	graded = mix(graded, contact_shadow_color.rgb,
			contact_shadow * contact_shadow_strength * texel.a);
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
	COLOR = vec4(graded, texel.a * visibility);
}
