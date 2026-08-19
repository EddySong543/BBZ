shader_type canvas_item;

// Shared battle-world post process. Heat mirage defaults to zero so only
// scenes that opt in are affected. UI nodes render after this pass.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

group_uniforms lens;
uniform float barrel_amount : hint_range(-0.3, 0.3) = 0.06;
uniform float barrel_edge_margin : hint_range(0.02, 0.4) = 0.15;
uniform float edge_blur_amount : hint_range(0.0, 4.0) = 1.2;
uniform float edge_blur_start : hint_range(0.0, 1.0) = 0.45;
group_uniforms;

group_uniforms grade;
uniform float brightness : hint_range(0.5, 1.5) = 0.97;
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float saturation : hint_range(0.0, 2.0) = 0.88;
uniform vec3 tint_color : source_color = vec3(0.85, 0.92, 1.10);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.40;
group_uniforms;

group_uniforms split_tone;
uniform vec3 shadow_tint : source_color = vec3(0.88, 0.94, 1.08);
uniform vec3 highlight_tint : source_color = vec3(1.06, 1.00, 0.90);
uniform float split_strength : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

group_uniforms vignette;
uniform vec3 vignette_color : source_color = vec3(0.012, 0.020, 0.047);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.40;
uniform float vignette_radius : hint_range(0.3, 1.2) = 0.90;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.55;
group_uniforms;

group_uniforms grain;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.02;
uniform float grain_scale : hint_range(0.5, 4.0) = 1.6;
group_uniforms;

group_uniforms heat_mirage;
uniform float heat_haze_strength : hint_range(0.0, 3.0, 0.05) = 0.0;
uniform float heat_haze_speed : hint_range(0.0, 1.5, 0.01) = 0.34;
uniform float heat_haze_scale : hint_range(2.0, 18.0, 0.1) = 8.4;
uniform float heat_haze_top_weight : hint_range(0.0, 1.0, 0.01) = 0.20;
uniform float heat_haze_lower_focus : hint_range(0.0, 0.8, 0.01) = 0.10;
uniform float heat_haze_vertical : hint_range(0.0, 0.5, 0.01) = 0.16;
uniform float heat_haze_character_protection : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec2 heat_haze_p1_center = vec2(0.25, 0.58);
uniform vec2 heat_haze_p2_center = vec2(0.75, 0.58);
uniform vec2 heat_haze_character_radius = vec2(0.15, 0.34);
group_uniforms;

group_uniforms impact_frame;
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;
uniform float impact_invert : hint_range(0.0, 1.0) = 0.0;
uniform vec2 impact_center = vec2(0.5, 0.55);
uniform float impact_burst_radius : hint_range(0.05, 0.8) = 0.26;
uniform float impact_jag : hint_range(0.0, 0.3) = 0.11;
uniform float impact_jag_freq = 7.0;
uniform float impact_th_out : hint_range(0.0, 1.0) = 0.52;
uniform float impact_th_in : hint_range(0.0, 1.0) = 0.13;
uniform float impact_white : hint_range(0.5, 1.0) = 0.86;
uniform float impact_px = 3.0;
group_uniforms;


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}


vec2 rising_refraction(vec2 screen_uv, vec2 screen_pixel_size) {
	float rise = TIME * heat_haze_speed;
	float vertical_weight = mix(
			heat_haze_top_weight,
			1.0,
			smoothstep(heat_haze_lower_focus, 0.90, screen_uv.y));
	float broad = sin(
			screen_uv.y * heat_haze_scale * 6.2831853
			- rise * 6.2831853
			+ sin(screen_uv.x * 11.0 + rise * 1.7) * 0.48);
	float fine = sin(
			screen_uv.y * heat_haze_scale * 11.7
			- rise * 10.3
			- screen_uv.x * 5.1);
	float field = broad * 0.68 + fine * 0.32;
	vec2 heat_haze_offset = vec2(
			field * screen_pixel_size.x,
			fine * screen_pixel_size.y * heat_haze_vertical);
	vec2 p1_delta = (screen_uv - heat_haze_p1_center)
			/ max(heat_haze_character_radius, vec2(0.001));
	vec2 p2_delta = (screen_uv - heat_haze_p2_center)
			/ max(heat_haze_character_radius, vec2(0.001));
	float p1_protection = 1.0 - smoothstep(0.72, 1.12, length(p1_delta));
	float p2_protection = 1.0 - smoothstep(0.72, 1.12, length(p2_delta));
	float character_protection = max(p1_protection, p2_protection)
			* heat_haze_character_protection;
	return heat_haze_offset
			* heat_haze_strength
			* vertical_weight
			* (1.0 - character_protection);
}


void fragment() {
	vec2 refracted_uv = clamp(
			SCREEN_UV + rising_refraction(SCREEN_UV, SCREEN_PIXEL_SIZE),
			vec2(0.0),
			vec2(1.0));
	vec2 center_delta = refracted_uv - vec2(0.5);
	float radius_squared = dot(center_delta, center_delta);
	float distance_from_center = length(SCREEN_UV - vec2(0.5)) * 1.4142;
	vec2 edge_fade = smoothstep(
			vec2(0.0),
			vec2(barrel_edge_margin),
			refracted_uv);
	edge_fade *= smoothstep(
			vec2(0.0),
			vec2(barrel_edge_margin),
			vec2(1.0) - refracted_uv);
	vec2 sample_uv = clamp(
			refracted_uv
			+ center_delta * radius_squared * barrel_amount * edge_fade,
			vec2(0.0),
			vec2(1.0));

	vec3 color;
	if (edge_blur_amount <= 0.0001) {
		color = texture(screen_tex, sample_uv).rgb;
	} else {
		float blur_weight = smoothstep(
				edge_blur_start,
				1.0,
				distance_from_center) * edge_blur_amount;
		vec2 blur_pixel = SCREEN_PIXEL_SIZE * blur_weight * 2.5;
		vec2 safe_uv = clamp(sample_uv, blur_pixel, vec2(1.0) - blur_pixel);
		color = texture(screen_tex, safe_uv).rgb * 0.4;
		color += texture(screen_tex, safe_uv + vec2(blur_pixel.x, 0.0)).rgb * 0.15;
		color += texture(screen_tex, safe_uv - vec2(blur_pixel.x, 0.0)).rgb * 0.15;
		color += texture(screen_tex, safe_uv + vec2(0.0, blur_pixel.y)).rgb * 0.15;
		color += texture(screen_tex, safe_uv - vec2(0.0, blur_pixel.y)).rgb * 0.15;
	}

	color *= brightness;
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);
	color = mix(color, color * tint_color, tint_strength);
	vec3 toned = color * mix(
			shadow_tint,
			highlight_tint,
			clamp(luma, 0.0, 1.0));
	color = mix(color, toned, split_strength);

	float vignette = smoothstep(
			vignette_radius,
			vignette_radius - vignette_softness,
			distance_from_center);
	color = mix(
			mix(vignette_color, color, vignette),
			color,
			1.0 - vignette_strength);
	float grain = hash(
			SCREEN_UV / max(SCREEN_PIXEL_SIZE.y, 0.00001)
			* 0.01 * grain_scale) - 0.5;
	color += grain * grain_amount;

	if (impact_strength > 0.0001) {
		vec2 impact_uv = floor(
				SCREEN_UV / (SCREEN_PIXEL_SIZE * impact_px))
				* SCREEN_PIXEL_SIZE * impact_px;
		vec2 impact_delta = impact_uv - impact_center;
		impact_delta.x *= SCREEN_PIXEL_SIZE.y
				/ max(SCREEN_PIXEL_SIZE.x, 0.000001);
		float impact_angle = atan(impact_delta.y, impact_delta.x);
		float jag = hash(vec2(
				floor(impact_angle * impact_jag_freq), 7.31)) * 0.7;
		jag += hash(vec2(
				floor(impact_angle * impact_jag_freq * 3.0), 3.17)) * 0.3;
		float impact_radius = impact_burst_radius
				+ (jag - 0.5) * 2.0 * impact_jag;
		float burst = 1.0 - step(impact_radius, length(impact_delta));
		float impact_luma = dot(color, vec3(0.299, 0.587, 0.114));
		float binary_value = step(
				mix(impact_th_out, impact_th_in, burst),
				impact_luma);
		binary_value = mix(binary_value, 1.0 - binary_value, impact_invert);
		color = mix(
				color,
				vec3(binary_value * impact_white),
				impact_strength);
	}

	COLOR = vec4(color, 1.0);
}
