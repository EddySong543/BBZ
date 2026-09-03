shader_type canvas_item;
render_mode unshaded;

group_uniforms ridge_wind;
uniform float motion_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float ridge_start_x : hint_range(0.0, 1.0, 0.01) = 0.02;
uniform float ridge_end_x : hint_range(0.0, 1.0, 0.01) = 0.98;
uniform float ridge_start_y : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float ridge_end_y : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform float ridge_curve_power : hint_range(0.3, 2.0, 0.05) = 0.75;
uniform float ridge_band : hint_range(0.01, 0.12, 0.005) = 0.045;
uniform float ridge_feather : hint_range(0.005, 0.08, 0.005) = 0.015;
uniform float cycle_sec : hint_range(8.0, 20.0, 0.1) = 12.8;
uniform float sway_px : hint_range(0.0, 1.5, 0.05) = 0.65;
uniform float detail_px : hint_range(0.0, 0.8, 0.05) = 0.2;
uniform float lift_px : hint_range(0.0, 0.8, 0.05) = 0.2;
uniform float phase_seed : hint_range(0.0, 12.0, 0.1) = 1.3;
group_uniforms;

group_uniforms field_light;
uniform float field_depth : hint_range(0.04, 0.4, 0.01) = 0.22;
uniform float field_wave_strength : hint_range(0.0, 0.3, 0.01) = 0.1;
uniform float field_wave_speed : hint_range(0.0, 0.08, 0.001) = 0.022;
uniform vec4 field_wave_color : source_color = vec4(0.93, 0.96, 0.96, 1.0);
group_uniforms;

group_uniforms depth_grade;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float contrast : hint_range(0.5, 1.5, 0.01) = 1.0;
uniform float palette_steps : hint_range(8.0, 64.0, 1.0) = 20.0;
uniform float palette_remap_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 palette_shadow_color : source_color = vec4(0.45, 0.55, 0.71, 1.0);
uniform vec4 palette_mid_color : source_color = vec4(0.61, 0.71, 0.83, 1.0);
uniform vec4 palette_highlight_color : source_color = vec4(0.93, 0.96, 0.96, 1.0);
group_uniforms;


float ridge_y_at(float x) {
	float span = max(ridge_end_x - ridge_start_x, 0.001);
	float progress = clamp((x - ridge_start_x) / span, 0.0, 1.0);
	return mix(ridge_start_y, ridge_end_y, pow(progress, ridge_curve_power));
}


float ridge_weight(vec2 uv) {
	float x_gate = smoothstep(
			ridge_start_x - ridge_feather, ridge_start_x + ridge_feather, uv.x)
			* (1.0 - smoothstep(
				ridge_end_x - ridge_feather, ridge_end_x + ridge_feather, uv.x));
	float distance_to_ridge = abs(uv.y - ridge_y_at(uv.x));
	float band = 1.0 - smoothstep(
			ridge_band, ridge_band + ridge_feather, distance_to_ridge);
	return x_gate * band;
}


void vertex() {
	float weight = ridge_weight(UV) * motion_strength;
	float world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
	float phase = TIME * TAU / max(cycle_sec, 0.001)
			+ world_x * 0.011 + phase_seed;
	float primary = sin(phase);
	float secondary = sin(phase * 0.63 - 0.9);
	float detail = sin(phase * 1.91 + UV.x * TAU * 1.7);
	VERTEX.x += (sway_px * (primary * 0.72 + secondary * 0.28)
			+ detail_px * detail) * weight;
	VERTEX.y -= lift_px * (primary * 0.5 + 0.5) * weight;
}


void fragment() {
	vec4 tex = texture(TEXTURE, UV);
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

	float ridge_y = ridge_y_at(UV.x);
	float below_ridge = UV.y - ridge_y;
	float field_mask = step(-ridge_feather, below_ridge)
			* (1.0 - smoothstep(field_depth * 0.72, field_depth, below_ridge));
	float field_center = fract(TIME * field_wave_speed + phase_seed * 0.071);
	float field_distance = abs(fract(UV.x - field_center + 0.5) - 0.5);
	float field_wave = 1.0 - smoothstep(0.06, 0.18, field_distance);
	graded = mix(graded, field_wave_color.rgb,
			field_wave * field_mask * field_wave_strength * motion_strength * tex.a);

	float steps = max(palette_steps - 1.0, 1.0);
	graded = floor(clamp(graded, vec3(0.0), vec3(1.0))
			* steps + 0.5) / steps;
	COLOR = vec4(graded, tex.a * tint_color.a);
}
