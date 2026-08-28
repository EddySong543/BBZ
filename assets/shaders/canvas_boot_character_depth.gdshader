shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 pointer_tilt = vec2(0.0);
uniform vec2 perspective_pivot = vec2(0.56, 0.50);
uniform float pointer_yaw_strength : hint_range(0.0, 0.12, 0.001) = 0.052;
uniform float pointer_pitch_strength : hint_range(0.0, 0.08, 0.001) = 0.021;
uniform float front_hand_start : hint_range(0.5, 0.9, 0.01) = 0.62;
uniform float front_hand_depth_boost : hint_range(1.0, 1.6, 0.01) = 1.25;
uniform vec2 hand_center = vec2(0.82, 0.32);
uniform vec2 hand_radius = vec2(0.27, 0.34);
uniform float blur_texels : hint_range(0.0, 2.0, 0.1) = 1.0;
uniform float blur_mix : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float desaturation : hint_range(0.0, 0.25, 0.01) = 0.06;
uniform float blue_replacement_strength : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform vec4 blue_shadow_target : source_color = vec4(0.188235, 0.196078, 0.207843, 1.0);
uniform vec4 blue_highlight_target : source_color = vec4(0.466667, 0.450980, 0.419608, 1.0);
uniform vec2 rear_energy_center = vec2(0.3532, 0.2756);
uniform vec2 rear_light_radius = vec2(0.22, 0.30);
uniform vec4 rear_light_color : source_color = vec4(
		0.909804, 0.784314, 0.439216, 1.0);
uniform float rear_light_strength : hint_range(0.0, 0.3, 0.01) = 0.14;
uniform float energy_phase : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec2 energy_transfer_center = vec2(0.505, 0.405);
uniform vec2 energy_transfer_radius = vec2(0.20, 0.23);
uniform float energy_transfer_strength : hint_range(0.0, 0.12, 0.005) = 0.045;
uniform float intro_light_progress : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float intro_silhouette_floor : hint_range(0.0, 0.2, 0.005) = 0.0;
uniform float intro_impact_progress : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform vec4 intro_impact_color : source_color = vec4(
		1.0, 0.76, 0.28, 1.0);
uniform float intro_impact_strength : hint_range(0.0, 0.3, 0.005) = 0.14;

varying vec4 vertex_color;


vec3 replace_blue_cloth_family(vec3 sampled_color) {
	float luminance = dot(sampled_color, vec3(0.299, 0.587, 0.114));
	// Only the authored blue cloth family can enter this mask. Warm skin and brown
	// materials have B <= max(R, G), so they remain byte-for-byte untouched here.
	float blue_dominance = sampled_color.b - max(sampled_color.r, sampled_color.g);
	float blue_mask = smoothstep(0.025, 0.085, blue_dominance);
	float value_position = smoothstep(0.10, 0.62, luminance);
	vec3 graphite = mix(
			blue_shadow_target.rgb,
			blue_highlight_target.rgb,
			value_position);
	return mix(
			sampled_color,
			graphite,
			blue_mask * clamp(blue_replacement_strength, 0.0, 1.0));
}


void vertex() {
	vertex_color = COLOR;
}


vec2 perspective_source_uv(vec2 display_uv) {
	vec2 local_uv = display_uv - perspective_pivot;
	float front_mask = smoothstep(
			front_hand_start,
			0.98,
			display_uv.x);
	float depth_axis = local_uv.x * mix(
			1.0,
			front_hand_depth_boost,
			front_mask);
	float pointer_scale = max(
			1.0
				+ depth_axis
					* pointer_tilt.x
					* pointer_yaw_strength
				+ local_uv.y
					* pointer_tilt.y
					* pointer_pitch_strength,
			0.88);
	return perspective_pivot + local_uv / pointer_scale;
}


void fragment() {
	vec2 source_uv = perspective_source_uv(UV);
	bool inside_bounds = (
			source_uv.x >= 0.0
			&& source_uv.x <= 1.0
			&& source_uv.y >= 0.0
			&& source_uv.y <= 1.0);
	float bounds_mask = float(inside_bounds);
	source_uv = clamp(source_uv, vec2(0.0), vec2(1.0));

	vec2 texel = TEXTURE_PIXEL_SIZE * blur_texels;
	vec4 source = texture(TEXTURE, source_uv);
	vec4 blurred = (
			source * 2.0
			+ texture(TEXTURE, source_uv + vec2(texel.x, 0.0))
			+ texture(TEXTURE, source_uv - vec2(texel.x, 0.0))
			+ texture(TEXTURE, source_uv + vec2(0.0, texel.y))
			+ texture(TEXTURE, source_uv - vec2(0.0, texel.y))
		) / 6.0;

	vec2 safe_radius = max(hand_radius, vec2(0.001));
	float ellipse_distance = length(
			(source_uv - hand_center) / safe_radius);
	float hand_mask = 1.0 - smoothstep(0.78, 1.08, ellipse_distance);
	float foreground_mask = smoothstep(0.62, 0.94, source_uv.x);
	float depth_mask = hand_mask * foreground_mask;

	vec4 result = mix(
			source,
			blurred,
			depth_mask * clamp(blur_mix, 0.0, 1.0));
	result.rgb = replace_blue_cloth_family(result.rgb);
	float gray = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	result.rgb = mix(
			result.rgb,
			vec3(gray),
			depth_mask * clamp(desaturation, 0.0, 0.25));

	vec2 safe_light_radius = max(rear_light_radius, vec2(0.001));
	float rear_distance = length(
			(source_uv - rear_energy_center) / safe_light_radius);
	float rear_falloff = (
			1.0 - smoothstep(0.12, 1.0, rear_distance));
	float energy_pulse = (
			0.82
			+ 0.18
			* (0.5 + 0.5 * sin(energy_phase * 6.2831853)));
	float surface_luminance = max(
			result.r,
			max(result.g, result.b));
	float surface_response = mix(
			0.28,
			1.0,
			smoothstep(0.08, 0.58, surface_luminance));
	float warm_light = (
			rear_falloff
			* energy_pulse
			* surface_response
			* clamp(rear_light_strength, 0.0, 0.3)
			* source.a);
	result.rgb = min(
			vec3(1.0),
			result.rgb + rear_light_color.rgb * warm_light);

	// The hand pulse reaches the rear shoulder and upper torso as a restrained
	// surface response. It changes the existing pixels instead of adding a
	// detached glow or a travelling scan band.
	vec2 safe_transfer_radius = max(
			energy_transfer_radius,
			vec2(0.001));
	float transfer_distance = length(
			(source_uv - energy_transfer_center) / safe_transfer_radius);
	float transfer_mask = 1.0 - smoothstep(0.42, 1.0, transfer_distance);
	float delayed_energy_pulse = (
			0.5
			+ 0.5
			* sin((energy_phase - 0.08) * 6.2831853));
	float transfer_light = (
			transfer_mask
			* delayed_energy_pulse
			* surface_response
			* clamp(energy_transfer_strength, 0.0, 0.12)
			* source.a);
	result.rgb = min(
			vec3(1.0),
			result.rgb + rear_light_color.rgb * transfer_light);

	// A single expanding light band carries the hand impact across the
	// character. At progress 0 and 1 its envelope is zero, so the approved
	// idle grade remains byte-for-byte equivalent at both endpoints.
	float safe_impact_progress = clamp(
			intro_impact_progress,
			0.0,
			1.0);
	float impact_envelope = max(
			sin(safe_impact_progress * 3.14159265),
			0.0);
	float impact_radius = mix(
			0.10,
			1.08,
			smoothstep(0.0, 1.0, safe_impact_progress));
	float impact_band = (
			1.0
			- smoothstep(
					0.08,
					0.24,
					abs(rear_distance - impact_radius)));
	float impact_fill = (
			1.0
			- smoothstep(
					impact_radius * 0.38,
					max(impact_radius, 0.001),
					rear_distance));
	float impact_light = (
			(impact_band + impact_fill * 0.24)
			* impact_envelope
			* surface_response
			* clamp(intro_impact_strength, 0.0, 0.3)
			* source.a);
	result.rgb = min(
			vec3(1.0),
			result.rgb + intro_impact_color.rgb * impact_light);

	// Lift the whole character's exposure while a broad, soft hand light
	// leads the change. There is no moving UV boundary, so detached hair
	// pieces and the upper-right silhouette cannot expose a mask seam.
	float safe_intro_progress = clamp(
			intro_light_progress,
			0.0,
			1.0);
	float global_lift = smoothstep(
			0.08,
			0.96,
			safe_intro_progress);
	float hand_lead = smoothstep(
			0.0,
			0.30,
			safe_intro_progress);
	float broad_hand_light = (
			1.0
			- smoothstep(0.05, 1.08, rear_distance));
	float intro_light = max(
			global_lift,
			broad_hand_light * hand_lead);
	float intro_brightness = mix(
			clamp(intro_silhouette_floor, 0.0, 0.2),
			1.0,
			intro_light);
	result.rgb *= intro_brightness;
	COLOR = result * vertex_color;
	COLOR.a *= bounds_mask;
}
