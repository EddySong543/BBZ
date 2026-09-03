shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint_color : source_color = vec4(1.0);
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.5, 0.01) = 1.0;
uniform float palette_steps : hint_range(8.0, 64.0, 1.0) = 20.0;
uniform float palette_remap_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 palette_shadow_color : source_color = vec4(0.08, 0.24, 0.27, 1.0);
uniform vec4 palette_mid_color : source_color = vec4(0.33, 0.42, 0.52, 1.0);
uniform vec4 palette_highlight_color : source_color = vec4(0.67, 0.77, 0.93, 1.0);

group_uniforms contact_interlock;
uniform bool contact_enabled = false;
uniform sampler2D contact_right_texture;
uniform vec4 self_scene_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 contact_right_rect_a = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 contact_right_rect_b = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 contact_cluster_size = vec2(18.0, 12.0);
uniform bool contact_shadow_enabled = false;
uniform vec4 contact_shadow_color : source_color = vec4(0.18, 0.25, 0.31, 1.0);
uniform float contact_shadow_strength : hint_range(0.0, 0.5, 0.01) = 0.24;
uniform float contact_shadow_radius_px : hint_range(2.0, 24.0, 1.0) = 12.0;
uniform vec2 contact_shadow_offset_px = vec2(0.0, 6.0);
group_uniforms;


float inside_scene_rect(vec2 scene_position, vec4 scene_rect) {
	vec2 minimum = step(scene_rect.xy, scene_position);
	vec2 maximum = step(scene_position, scene_rect.xy + scene_rect.zw);
	return minimum.x * minimum.y * maximum.x * maximum.y;
}


float sample_layer_alpha(vec4 scene_rect, vec2 scene_position) {
	vec2 layer_uv = (scene_position - scene_rect.xy) / max(scene_rect.zw, vec2(0.001));
	return texture(contact_right_texture, clamp(layer_uv, vec2(0.0), vec2(1.0))).a
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


float right_grass_alpha(vec2 scene_position) {
	return max(
			sample_layer_alpha(contact_right_rect_a, scene_position),
			sample_layer_alpha(contact_right_rect_b, scene_position));
}


float soft_contact_alpha(vec2 scene_position) {
	float radius = contact_shadow_radius_px;
	vec2 origin = scene_position - contact_shadow_offset_px;
	float result = right_grass_alpha(origin) * 4.0;
	result += right_grass_alpha(origin + vec2(radius, 0.0)) * 2.0;
	result += right_grass_alpha(origin - vec2(radius, 0.0)) * 2.0;
	result += right_grass_alpha(origin + vec2(0.0, radius)) * 2.0;
	result += right_grass_alpha(origin - vec2(0.0, radius)) * 2.0;
	result += right_grass_alpha(origin + vec2(radius, radius));
	result += right_grass_alpha(origin + vec2(radius, -radius));
	result += right_grass_alpha(origin + vec2(-radius, radius));
	result += right_grass_alpha(origin - vec2(radius, radius));
	return result / 16.0;
}


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float visibility = 1.0;
	float contact_shadow = 0.0;
	if (contact_enabled || contact_shadow_enabled) {
		vec2 scene_position = self_scene_rect.xy + UV * self_scene_rect.zw;
		float grass_alpha = right_grass_alpha(scene_position);
		float grass_claim = interlock_cluster(scene_position);
		float platform_surface = surface_band(
				tex.a,
				texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a,
				texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a,
				texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a);
		if (contact_enabled) {
			float contact_cut = platform_surface
					* step(0.5, grass_alpha) * grass_claim;
			visibility *= 1.0 - contact_cut;
		}
		if (contact_shadow_enabled) {
			contact_shadow = platform_surface * soft_contact_alpha(scene_position);
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
	graded = mix(graded, contact_shadow_color.rgb,
			contact_shadow * contact_shadow_strength);
	float steps = max(palette_steps - 1.0, 1.0);
	graded = floor(clamp(graded, vec3(0.0), vec3(1.0))
			* steps + 0.5) / steps;
	COLOR = vec4(graded, tex.a * tint_color.a * visibility);
}
