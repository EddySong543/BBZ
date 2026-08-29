shader_type canvas_item;
render_mode unshaded;

// Scene8's sky is a clear polar night, not Scene1's empty deep-night field.
// A chromatic three-stage base keeps the luminance readable without washing
// the middle sky in grey. The mountain airglow remains local and irregular.

group_uniforms polar_night;
uniform vec4 zenith_color : source_color = vec4(0.018, 0.048, 0.115, 1.0);
uniform vec4 upper_color : source_color = vec4(0.025, 0.083, 0.165, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.047, 0.154, 0.255, 1.0);
uniform float upper_transition : hint_range(0.1, 0.7, 0.01) = 0.38;
uniform float horizon_transition : hint_range(0.35, 0.9, 0.01) = 0.62;
uniform float scene_exposure : hint_range(0.5, 1.5, 0.01) = 1.0;
group_uniforms;

group_uniforms mountain_airglow;
uniform vec4 airglow_blue : source_color = vec4(0.07, 0.29, 0.49, 1.0);
uniform vec4 airglow_green : source_color = vec4(0.045, 0.40, 0.33, 1.0);
uniform vec4 airglow_violet : source_color = vec4(0.29, 0.13, 0.47, 1.0);
uniform float airglow_center : hint_range(0.15, 0.7, 0.01) = 0.41;
uniform float airglow_width : hint_range(0.05, 0.4, 0.01) = 0.145;
uniform float airglow_strength : hint_range(0.0, 0.5, 0.01) = 0.115;
uniform float airglow_irregularity : hint_range(0.0, 0.2, 0.005) = 0.065;
uniform float airglow_drift : hint_range(0.0, 0.03, 0.001) = 0.003;
group_uniforms;

group_uniforms mountain_green_veil;
uniform vec4 horizon_green_color : source_color = vec4(0.035, 0.34, 0.24, 1.0);
uniform float horizon_green_start : hint_range(0.15, 0.6, 0.01) = 0.29;
uniform float horizon_green_crest : hint_range(0.3, 0.75, 0.01) = 0.50;
uniform float horizon_green_fade_end : hint_range(0.45, 0.9, 0.01) = 0.68;
uniform float horizon_green_strength : hint_range(0.0, 0.4, 0.01) = 0.14;
uniform float horizon_green_irregularity : hint_range(0.0, 0.1, 0.005) = 0.025;
group_uniforms;

group_uniforms sky_texture;
uniform float texture_strength : hint_range(0.0, 0.2, 0.005) = 0.018;
uniform float dither_amount : hint_range(0.0, 0.04, 0.001) = 0.002;
uniform int posterize_steps : hint_range(16, 256, 1) = 144;
uniform vec2 pixel_grid = vec2(320.0, 180.0);
uniform float diagnostic_time_sec : hint_range(-1.0, 300.0, 0.1) = -1.0;
group_uniforms;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float fbm(vec2 p) {
	float sum = 0.0;
	float weight = 0.56;
	for (int octave = 0; octave < 3; octave++) {
		sum += value_noise(p) * weight;
		p = p * 2.03 + vec2(3.17, 5.83);
		weight *= 0.48;
	}
	return sum / 0.962;
}


float bell(float value, float center, float width) {
	float distance_to_center = (value - center) / max(width, 0.001);
	return exp(-distance_to_center * distance_to_center);
}


void fragment() {
	float fx_time = diagnostic_time_sec >= 0.0 ? diagnostic_time_sec : TIME;
	vec2 pixel_uv = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	float y = pixel_uv.y;

	// Two eased transitions create a three-stage polar-night field. Neither
	// transition coincides with the airglow crest, avoiding a visible ramp.
	float upper_mix = smoothstep(0.03, upper_transition, pow(y, 0.90));
	float horizon_mix = smoothstep(
			horizon_transition - 0.20,
			horizon_transition + 0.18,
			pow(y, 1.08));
	vec3 color = mix(zenith_color.rgb, upper_color.rgb, upper_mix);
	color = mix(color, horizon_color.rgb, horizon_mix);

	// Wide and narrow noise fields bend the atmospheric crest independently.
	// This is the shallow transition from the mountain boundary to the aurora:
	// a layered veil with broken density, not a bottom-to-top gradient.
	float slow_time = fx_time * airglow_drift;
	float broad_noise = fbm(vec2(pixel_uv.x * 2.25 + slow_time, y * 1.25 + 1.7));
	float ridge_noise = value_noise(vec2(
			pixel_uv.x * 6.1 - slow_time * 0.73,
			6.4 + slow_time * 0.31));
	float bent_center = airglow_center
			+ (broad_noise - 0.5) * airglow_irregularity
			+ (ridge_noise - 0.5) * airglow_irregularity * 0.32;
	float lower_veil = bell(y, bent_center, airglow_width);
	float upper_echo = bell(
			y,
			bent_center - airglow_width * 0.72,
			airglow_width * 0.52);
	float band_breakup = mix(
			0.70,
			1.0,
			fbm(vec2(pixel_uv.x * 4.4 + 8.2, y * 7.0 - slow_time * 0.41)));
	float layered_airglow = clamp(
			(lower_veil * 0.74 + upper_echo * 0.26) * band_breakup,
			0.0,
			1.0);

	// Slowly changing spectral fields echo the accepted green/cyan/violet
	// curtain without drawing another aurora silhouette into the background.
	float green_field = smoothstep(
			0.24,
			0.82,
			fbm(vec2(pixel_uv.x * 1.85 + 2.3, 3.2 + slow_time * 0.22)));
	float violet_field = smoothstep(
			0.38,
			0.88,
			fbm(vec2(pixel_uv.x * 2.35 + 9.7, 7.1 - slow_time * 0.17)));
	vec3 atmospheric_color = mix(
			airglow_blue.rgb,
			airglow_green.rgb,
			green_field * 0.62);
	atmospheric_color = mix(
			atmospheric_color,
			airglow_violet.rgb,
			violet_field * 0.30);
	color += atmospheric_color * layered_airglow * airglow_strength;

	// A restrained green veil rises only above the authored mountain boundary.
	// Two differently scaled fields bend its edge and density so it reads as
	// auroral atmosphere, never as a straight bottom-to-top gradient.
	float veil_noise = fbm(vec2(
			pixel_uv.x * 3.15 + 4.7 - slow_time * 0.18,
			5.2 + y * 1.7 + slow_time * 0.09));
	float veil_ridge = value_noise(vec2(
			pixel_uv.x * 7.4 + 11.3,
			8.6 - slow_time * 0.13));
	float veil_bend = ((veil_noise - 0.5) * 0.72
			+ (veil_ridge - 0.5) * 0.28) * horizon_green_irregularity;
	float horizon_rise = smoothstep(
			horizon_green_start + veil_bend,
			horizon_green_crest + veil_bend * 0.35,
			y);
	float horizon_falloff = 1.0 - smoothstep(
			horizon_green_crest + 0.05,
			horizon_green_fade_end,
			y);
	float horizon_green_veil = horizon_rise * horizon_falloff
			* mix(0.78, 1.0, veil_noise);
	color = mix(
			color,
			horizon_green_color.rgb,
			horizon_green_veil * horizon_green_strength);

	// Very low contrast structure prevents the empty-flat-sky impression while
	// remaining much slower and quieter than the aurora curtain itself.
	float sky_structure = fbm(vec2(
			pixel_uv.x * 2.7 - slow_time * 0.31,
			y * 2.1 + slow_time * 0.12));
	color *= 1.0 + (sky_structure - 0.5) * texture_strength;
	color *= scene_exposure;

	vec2 fragment_cell = floor(UV * pixel_grid);
	float steps = float(posterize_steps);
	color += (hash21(fragment_cell + vec2(19.0, 37.0)) - 0.5) * dither_amount;
	color = floor(max(color, vec3(0.0)) * steps + 0.5) / steps;
	COLOR = vec4(color, 1.0);
}
