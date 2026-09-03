group_uniforms click_response;
uniform vec4 click_wave_0 = vec4(0.0);
uniform vec4 click_wave_1 = vec4(0.0);
uniform vec4 click_wave_2 = vec4(0.0);
uniform float click_wave_duration_sec = 1.55;
uniform float click_wave_speed_px = 360.0;
uniform float click_wave_band_px = 62.0;
uniform float click_press_radius_px = 118.0;
uniform float click_displacement_px = 0.72;
uniform float click_highlight_strength = 0.16;
uniform vec4 click_highlight_color : source_color = vec4(0.93, 0.97, 1.0, 1.0);
group_uniforms;


vec3 scene9_one_grass_click(float scene_x, vec4 wave) {
	float active = step(0.5, wave.w);
	float normalized_age = clamp(
			wave.y / max(click_wave_duration_sec, 0.001), 0.0, 1.0);
	float envelope = (1.0 - smoothstep(0.70, 1.0, normalized_age))
			* wave.z * active;
	float delta_x = scene_x - wave.x;
	float distance_x = abs(delta_x);
	float press = (1.0 - smoothstep(0.0, click_press_radius_px, distance_x))
			* (1.0 - smoothstep(0.10, 0.38, normalized_age));
	float front_radius = wave.y * click_wave_speed_px;
	float front_distance = abs(distance_x - front_radius);
	float bilateral_front = 1.0 - smoothstep(
			click_wave_band_px * 0.35, click_wave_band_px, front_distance);
	float direction_sign = sign(delta_x);
	return vec3(
			direction_sign * (bilateral_front * 0.82 + press * 0.16),
			press * 0.74 - bilateral_front * 0.32,
			max(press * 0.72, bilateral_front)) * envelope;
}


vec3 scene9_grass_click_response(float scene_x) {
	vec3 response = scene9_one_grass_click(scene_x, click_wave_0);
	response += scene9_one_grass_click(scene_x, click_wave_1);
	response += scene9_one_grass_click(scene_x, click_wave_2);
	response.xy = clamp(response.xy, vec2(-1.0), vec2(1.0));
	response.z = clamp(response.z, 0.0, 1.0);
	return response;
}
