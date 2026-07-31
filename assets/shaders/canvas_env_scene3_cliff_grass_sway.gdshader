shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D grass_mask : filter_nearest, repeat_disable;
uniform sampler2D underpaint_texture : filter_nearest, repeat_disable;
uniform vec2 red_pivot = vec2(0.5, 0.25);
uniform vec2 green_pivot = vec2(0.75, 0.25);
uniform float motion_fps : hint_range(2.0, 8.0, 1.0) = 6.0;
uniform float cycle_sec : hint_range(5.0, 14.0, 0.25) = 8.5;
uniform float red_angle_deg : hint_range(0.0, 1.2, 0.05) = 0.8;
uniform float green_angle_deg : hint_range(0.0, 1.2, 0.05) = 0.9;
uniform float phase_offset = 0.3;

uniform vec4 tint_color : source_color = vec4(0.58, 0.56, 0.53, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.20, 0.20, 0.19, 1.0);
uniform vec4 dawn_rim_color : source_color = vec4(0.98, 0.68, 0.43, 1.0);
uniform vec4 fog_color : source_color = vec4(0.64, 0.63, 0.61, 1.0);
uniform float saturation : hint_range(0.0, 1.25, 0.01) = 0.55;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.20;
uniform float rim_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float fog_strength : hint_range(0.0, 0.6, 0.01) = 0.22;
uniform float exposure : hint_range(0.6, 1.5, 0.01) = 1.18;
uniform float midtone_lift : hint_range(0.0, 0.2, 0.005) = 0.075;
uniform float alpha_scale : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float palette_steps : hint_range(8.0, 96.0, 1.0) = 32.0;
uniform vec2 artifact_cleanup_pixel = vec2(-1.0, -1.0);
uniform float artifact_cleanup_strength : hint_range(0.0, 1.0, 1.0) = 0.0;

uniform vec4 cloud_band_light_color : source_color = vec4(1.0, 0.79, 0.56, 1.0);
uniform vec4 cloud_band_shadow_color : source_color = vec4(0.24, 0.32, 0.32, 1.0);
uniform float cloud_band_light_strength : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform float cloud_band_shadow_strength : hint_range(0.0, 0.35, 0.01) = 0.0;
uniform float cloud_roll_speed : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float cloud_billow_speed : hint_range(0.0, 2.0, 0.01) = 0.82;
uniform float cloud_roll_phase = 2.1;
uniform float cloud_billow_phase = 1.7;
uniform float cloud_band_phase = 0.0;
uniform float cloud_band_slope : hint_range(0.0, 0.8, 0.01) = 0.34;
uniform float cloud_band_width : hint_range(0.04, 0.24, 0.005) = 0.105;
uniform float cloud_band_softness : hint_range(0.02, 0.16, 0.005) = 0.055;
uniform vec2 cloud_sun_screen_pos = vec2(0.51, 0.78);

varying vec4 node_modulate;


void vertex() {
	node_modulate = COLOR;
}


vec2 inverse_rotate_pixel_uv(
		vec2 destination_uv,
		vec2 pivot_uv,
		float angle,
		vec2 source_size) {
	vec2 delta_px = (destination_uv - pivot_uv) * source_size;
	float cosine = cos(-angle);
	float sine = sin(-angle);
	vec2 source_px = vec2(
			delta_px.x * cosine - delta_px.y * sine,
			delta_px.x * sine + delta_px.y * cosine);
	source_px = floor(source_px + pivot_uv * source_size + 0.5);
	return source_px / source_size;
}


vec4 alpha_over(vec4 under, vec4 over) {
	float output_alpha = over.a + under.a * (1.0 - over.a);
	vec3 output_rgb = over.rgb + under.rgb * (1.0 - over.a);
	return vec4(output_rgb, output_alpha);
}


vec2 cloud_light_band(vec2 screen_uv) {
	vec2 screen_grid = vec2(480.0, 270.0);
	vec2 suv = (
			floor(screen_uv * screen_grid) + vec2(0.5)
	) / screen_grid;
	float roll = sin(
			TIME * cloud_roll_speed
			+ cloud_roll_phase
			+ cloud_band_phase);
	float fold = sin(
			-TIME * cloud_roll_speed * 1.37
			+ cloud_roll_phase * 1.7
			+ cloud_band_phase * 0.63);
	float billow = sin(
			TIME * cloud_billow_speed
			+ cloud_billow_phase
			+ cloud_band_phase * 1.21);
	float cloud_signal = roll * 0.50 + fold * 0.20 + billow * 0.30;
	float band_center = 0.50 + cloud_signal * 0.18;
	float projected = suv.y
			+ abs(suv.x - cloud_sun_screen_pos.x) * cloud_band_slope;
	float light_distance = abs(projected - band_center);
	float light_band = 1.0 - smoothstep(
			cloud_band_width,
			cloud_band_width + cloud_band_softness,
			light_distance);
	float shadow_center = band_center + cloud_band_width * 2.35;
	float shadow_distance = abs(projected - shadow_center);
	float shadow_band = 1.0 - smoothstep(
			cloud_band_width * 1.15,
			cloud_band_width * 1.15 + cloud_band_softness * 1.4,
			shadow_distance);
	float vertical_gate = smoothstep(0.12, 0.30, suv.y)
			* (1.0 - smoothstep(0.94, 1.06, suv.y));
	return vec2(light_band, shadow_band) * vertical_gate;
}


void fragment() {
	vec2 source_size = vec2(textureSize(TEXTURE, 0));
	float stepped_time = floor(TIME * motion_fps) / motion_fps;
	float base_phase = stepped_time * TAU / max(cycle_sec, 0.001)
			+ phase_offset;
	float red_angle = sin(base_phase) * radians(red_angle_deg);
	float green_angle = sin(base_phase * 0.89 + 1.2)
			* radians(green_angle_deg);

	vec4 local_mask = texture(grass_mask, UV);
	local_mask.rgb *= local_mask.a;
	float red_here = local_mask.r;
	float green_here = local_mask.g;
	float moving_here = max(red_here, green_here);

	vec4 underpaint = texture(underpaint_texture, UV);
	underpaint.rgb *= underpaint.a;
	vec4 base = texture(TEXTURE, UV);
	vec2 source_pixel = floor(UV * source_size);
	float artifact_distance = max(
			abs(source_pixel.x - artifact_cleanup_pixel.x),
			abs(source_pixel.y - artifact_cleanup_pixel.y));
	float artifact = (1.0 - step(0.5, artifact_distance))
			* artifact_cleanup_strength;
	base.a *= 1.0 - artifact;
	base.a *= 1.0 - moving_here;
	base.rgb *= base.a;
	vec4 result = alpha_over(underpaint, base);

	vec2 red_uv = inverse_rotate_pixel_uv(
			UV, red_pivot, red_angle, source_size);
	float red_inside = step(0.0, red_uv.x) * step(red_uv.x, 1.0)
			* step(0.0, red_uv.y) * step(red_uv.y, 1.0);
	red_uv = clamp(red_uv, vec2(0.0), vec2(1.0));
	vec4 red_mask_sample = texture(grass_mask, red_uv);
	vec4 red_color = texture(TEXTURE, red_uv);
	red_color.a *= red_mask_sample.r * red_mask_sample.a * red_inside;
	red_color.rgb *= red_color.a;
	result = alpha_over(result, red_color);

	vec2 green_uv = inverse_rotate_pixel_uv(
			UV, green_pivot, green_angle, source_size);
	float green_inside = step(0.0, green_uv.x) * step(green_uv.x, 1.0)
			* step(0.0, green_uv.y) * step(green_uv.y, 1.0);
	green_uv = clamp(green_uv, vec2(0.0), vec2(1.0));
	vec4 green_mask_sample = texture(grass_mask, green_uv);
	vec4 green_color = texture(TEXTURE, green_uv);
	green_color.a *= green_mask_sample.g * green_mask_sample.a * green_inside;
	green_color.rgb *= green_color.a;
	result = alpha_over(result, green_color);

	if (result.a <= 0.001) {
		discard;
	}
	result.rgb /= result.a;
	vec4 tex = result;

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(vec3(luma), tex.rgb, saturation);
	vec3 color = mix(
			desaturated,
			tint_color.rgb * max(luma, 0.18),
			tint_strength);
	color = mix(
			color,
			fog_color.rgb,
			fog_strength * smoothstep(0.1, 0.9, UV.y));
	color = mix(
			color,
			color * shadow_color.rgb,
			shadow_strength * smoothstep(0.24, 1.0, UV.y));
	float midtone = smoothstep(0.08, 0.58, luma)
			* (1.0 - smoothstep(0.78, 1.0, luma));
	color = color * exposure + fog_color.rgb * midtone_lift * midtone;
	float rim = smoothstep(0.42, 1.0, UV.x)
			* (1.0 - smoothstep(0.0, 0.30, UV.y));
	color += dawn_rim_color.rgb * rim * rim_strength * tex.a;
	vec2 cloud_bands = cloud_light_band(SCREEN_UV);
	float surface_response = smoothstep(0.04, 0.62, luma)
			* (1.0 - smoothstep(0.90, 1.0, luma));
	color += cloud_band_light_color.rgb
			* cloud_bands.x
			* cloud_band_light_strength
			* (0.38 + surface_response * 0.62);
	color = mix(
			color,
			color * cloud_band_shadow_color.rgb,
			cloud_bands.y * cloud_band_shadow_strength);
	color = floor(
			clamp(color, vec3(0.0), vec3(1.0))
			* palette_steps + vec3(0.5)) / palette_steps;
	COLOR = vec4(
			color * node_modulate.rgb,
			tex.a * alpha_scale * node_modulate.a);
}
