shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D flow_texture : repeat_disable, filter_nearest;
uniform sampler2D intro_path_texture : repeat_disable, filter_nearest;
uniform float motion_time = 0.0;
uniform float flow_period : hint_range(2.0, 12.0, 0.1) = 5.2;
uniform float hand_flow_pixels : hint_range(0.0, 8.0, 0.1) = 2.5;
uniform float escape_flow_pixels : hint_range(0.0, 16.0, 0.5) = 4.0;
uniform float minimum_source_alpha : hint_range(0.5, 1.0, 0.01) = 0.72;
uniform float hand_motion_strength : hint_range(0.0, 0.5, 0.01) = 0.16;
uniform float escape_motion_strength : hint_range(0.0, 0.8, 0.01) = 0.38;
uniform float escape_highlight_strength : hint_range(0.0, 0.65, 0.01) = 0.52;
uniform vec3 escape_highlight_color = vec3(1.0, 0.86, 0.54);
uniform float intro_path_progress : hint_range(0.0, 1.0, 0.001) = 1.0;
uniform float intro_path_feather : hint_range(0.02, 0.24, 0.001) = 0.14;
uniform float intro_head_width : hint_range(0.02, 0.20, 0.001) = 0.075;
uniform vec2 intro_contact_min = vec2(0.48, 0.18);
uniform vec2 intro_contact_max = vec2(0.76, 0.52);
uniform float intro_late_path_threshold : hint_range(0.0, 1.0, 0.01) = 0.84;
uniform float intro_contact_path_ceiling : hint_range(0.0, 1.0, 0.01) = 0.32;

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


float hand_region(float flow_region) {
	return 1.0 - smoothstep(0.05, 0.14, abs(flow_region - 0.35));
}


float escape_region(float flow_region) {
	return smoothstep(0.72, 0.96, flow_region);
}


float circular_phase_distance(float first, float second) {
	return abs(fract(first - second + 0.5) - 0.5);
}


void fragment() {
	vec4 flow = texture(flow_texture, UV);
	vec2 direction = flow.rg * 2.0 - 1.0;
	float direction_length = length(direction);
	direction = direction_length > 0.001
			? direction / direction_length
			: vec2(0.0);

	float hand_mask = hand_region(flow.b);
	float escape_mask = escape_region(flow.b);
	float travel_pixels = (
			hand_mask * hand_flow_pixels
			+ escape_mask * escape_flow_pixels);

	float clock = (
			motion_time / max(flow_period, 0.001)
			+ flow.a * 0.08);
	float travel_phase = fract(clock);
	vec2 flow_offset = (
			direction
			* travel_phase
			* travel_pixels
			* TEXTURE_PIXEL_SIZE);
	vec4 transported = texture(
			TEXTURE,
			clamp(UV - flow_offset, vec2(0.0), vec2(1.0)));
	vec4 source = texture(TEXTURE, UV);

	// Keep the authored ring stable. Only a restrained portion of the hand
	// area and upper outer arc follows the flow map, and the source alpha
	// never drops below the configured floor.
	float motion_strength = (
			hand_mask * hand_motion_strength
			+ escape_mask * escape_motion_strength);
	float transported_coverage = smoothstep(
			0.06,
			0.58,
			transported.a);
	float effective_motion = (
			clamp(motion_strength, 0.0, 0.8)
			* transported_coverage);
	vec4 energy = vec4(
			mix(source.rgb, transported.rgb, effective_motion),
			mix(source.a, transported.a, effective_motion));
	energy.a = max(
			energy.a,
			source.a * clamp(minimum_source_alpha, 0.5, 1.0));

	// A brightness ridge travels continuously along the encoded outer arc.
	// This animates the original pixels rather than spawning a duplicate.
	float wave_phase = fract(motion_time / max(flow_period, 0.001));
	float wave_distance = circular_phase_distance(flow.a, wave_phase);
	float outer_wave = (
			escape_mask
			* (1.0 - smoothstep(0.035, 0.16, wave_distance)));
	energy.rgb = mix(
			energy.rgb,
			escape_highlight_color,
			outer_wave
			* clamp(escape_highlight_strength, 0.0, 0.65));

	// The path texture encodes a clockwise, source-aware paint order that
	// starts near the character's head. A wide irregular front prevents
	// the hard radial edge of an angular "windshield wiper" reveal.
	float source_path_progress = texture(
			intro_path_texture,
			UV).r;
	// The authored path contains a late-valued diagonal wedge over the
	// character contact area. Restrict that correction to existing gold
	// pixels around the rear arm/back: the local energy and its nearby
	// splashes now arrive with the source, while the outer arc keeps its
	// original clockwise order.
	float contact_region = (
			step(intro_contact_min.x, UV.x)
			* step(UV.x, intro_contact_max.x)
			* step(intro_contact_min.y, UV.y)
			* step(UV.y, intro_contact_max.y));
	float late_path = step(
			intro_late_path_threshold,
			source_path_progress);
	source_path_progress = mix(
			source_path_progress,
			min(source_path_progress, intro_contact_path_ceiling),
			contact_region * late_path * step(0.001, source.a));
	float intro_path_mask = smoothstep(
			source_path_progress - intro_path_feather,
			source_path_progress,
			intro_path_progress);
	float intro_head = (
			1.0
			- smoothstep(
					intro_head_width * 0.35,
					intro_head_width,
					abs(
						source_path_progress
						- intro_path_progress)));
	if (intro_path_progress <= 0.001) {
		intro_path_mask = 0.0;
		intro_head = 0.0;
	} else if (intro_path_progress >= 0.999) {
		intro_path_mask = 1.0;
		intro_head = 0.0;
	}
	energy.rgb = mix(
			energy.rgb,
			escape_highlight_color,
			intro_head * intro_path_mask * 0.22);
	energy = vec4(
			energy.rgb * intro_path_mask,
			energy.a * intro_path_mask);
	COLOR = energy * vertex_color;
}
