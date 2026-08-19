shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform int transition_mode : hint_enum(
	"Directional Cut", "Solid Ring", "Exposure Ring") = 2;
uniform vec2 energy_origin = vec2(0.553, 0.346);
uniform float aspect = 1.777778;
uniform sampler2D screen_texture
	: hint_screen_texture, filter_nearest;
uniform vec4 cover_color : source_color = vec4(
	0.168627, 0.207843, 0.258824, 1.0);
uniform vec4 cut_color : source_color = vec4(
	0.941176, 0.909804, 0.847059, 1.0);
uniform vec4 core_gold : source_color = vec4(
	0.886275, 0.705882, 0.352941, 1.0);
uniform vec4 ring_fill_color : source_color = vec4(
	1.0, 1.0, 1.0, 1.0);
uniform vec4 ring_edge_color : source_color = vec4(
	0.839216, 0.639216, 0.243137, 1.0);
uniform vec4 ring_energy_tint : source_color = vec4(
	1.0, 0.968627, 0.909804, 1.0);
uniform float ring_edge_half_width
	: hint_range(0.004, 0.024, 0.001) = 0.018;


float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}


vec3 energy_exposure_filter(
	vec3 input_color,
	float exposure_amount,
	float flash_amount
) {
	float source_luma = dot(
		input_color,
		vec3(0.2126, 0.7152, 0.0722));
	float posterized_luma = (
		floor(min(source_luma, 0.9999) * 3.0)
		/ 2.0);
	vec3 posterized_color = mix(
		vec3(posterized_luma),
		input_color,
		0.22);
	vec3 warm_energy = mix(
		posterized_color,
		ring_energy_tint.rgb,
		0.18 + exposure_amount * 0.18);
	vec3 exposed_color = mix(
		input_color,
		warm_energy,
		0.62 + exposure_amount * 0.18);
	return mix(
		exposed_color,
		vec3(1.0),
		clamp(flash_amount * 0.96, 0.0, 0.96));
}


void fragment() {
	vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(UV * viewport_size / 8.0);
	vec2 quantized_uv = (
		(cell + vec2(0.5)) * 8.0
		/ viewport_size
	);
	vec2 screen_cell = floor(
		SCREEN_UV * viewport_size / 8.0);
	vec2 pixelated_screen_uv = (
		(screen_cell + vec2(0.5)) * 8.0
		/ viewport_size
	);
	vec3 screen_color = texture(
		screen_texture,
		pixelated_screen_uv).rgb;
	vec2 delta = (
		(quantized_uv - energy_origin)
		* vec2(aspect, 1.0)
	);
	vec2 cut_direction = normalize(vec2(-aspect, 1.0));
	vec2 cut_normal = vec2(-cut_direction.y, cut_direction.x);
	float along_cut = dot(delta, cut_direction);
	float across_cut = dot(delta, cut_normal);
	vec2 cluster = floor(cell / vec2(4.0));
	float boundary_jitter = (hash21(cluster) - 0.5) * 0.008;
	float local_progress = (
		progress <= 1.0
		? clamp(progress, 0.0, 1.0)
		: clamp(progress - 1.0, 0.0, 1.0)
	);
	float mask = 0.0;
	float edge = 0.0;
	float core = 0.0;

	if (transition_mode == 0) {
		if (progress <= 1.0) {
			float line_progress = smoothstep(
				0.0, 0.30, local_progress);
			float plane_progress = pow(
				smoothstep(0.18, 1.0, local_progress),
				2.0);
			float reach = line_progress * 1.52;
			float line_reached = (
				step(-0.055, along_cut)
				* step(
					along_cut + boundary_jitter * 0.35,
					reach));
			float plane_reach = mix(
				0.08,
				1.52,
				smoothstep(0.18, 0.72, local_progress));
			float plane_reached = step(
				abs(along_cut) + boundary_jitter * 0.35,
				plane_reach);
			float half_width = mix(
				0.006, 1.34, plane_progress);
			float distance_to_plane = (
				abs(across_cut) + boundary_jitter);
			float plane_visible = step(
				0.001, plane_progress);
			float outer_plane = (
				step(
					distance_to_plane,
					half_width + 0.012)
				* plane_reached
				* plane_visible);
			float inner_plane = (
				step(
					distance_to_plane,
					max(half_width - 0.010, 0.0))
				* plane_reached
				* plane_visible);
			mask = (
				step(distance_to_plane, half_width)
				* plane_reached
				* plane_visible);
			edge = max(outer_plane - inner_plane, 0.0);
			float line_life = (
				1.0
				- smoothstep(
					0.36, 0.62, local_progress));
			float line_core = (
				(1.0 - smoothstep(
					0.003,
					0.010,
					abs(across_cut)))
				* line_reached
				* line_life);
			float hand_core = (
				1.0
				- smoothstep(
					0.02, 0.18, length(delta)));
			core = line_core * hand_core;
			edge = max(
				edge,
				line_core * (1.0 - hand_core * 0.72));
			if (local_progress <= 0.001) {
				mask = 0.0;
				edge = 0.0;
				core = 0.0;
			}
		} else {
			float sweep_threshold = mix(
				-1.34,
				1.34,
				local_progress);
			float revealed = step(
				along_cut + boundary_jitter,
				sweep_threshold);
			float reveal_outer = step(
				along_cut + boundary_jitter,
				sweep_threshold + 0.014);
			float reveal_inner = step(
				along_cut + boundary_jitter,
				sweep_threshold - 0.010);
			mask = 1.0 - revealed;
			edge = max(
				reveal_outer - reveal_inner,
				0.0);
			if (local_progress <= 0.001) {
				mask = 1.0;
				edge = 0.0;
			}
			if (local_progress >= 0.999) {
				mask = 0.0;
				edge = 0.0;
			}
		}
	} else {
		float ring_progress = smoothstep(
			0.0, 1.0, local_progress);
		float radius = mix(0.0, 1.13, ring_progress);
		float ring_distance = length(delta) + boundary_jitter;
		float outer_ring = step(
			ring_distance,
			radius + ring_edge_half_width);
		float inner_ring = step(
			ring_distance,
			max(radius - ring_edge_half_width, 0.0));
		edge = max(outer_ring - inner_ring, 0.0);
		core = 0.0;

		if (progress <= 1.0) {
			mask = step(ring_distance, radius);
			if (local_progress <= 0.001) {
				mask = 0.0;
				edge = 0.0;
				core = 0.0;
			}
		} else {
			mask = 1.0 - step(ring_distance, radius);
			if (local_progress <= 0.001) {
				mask = 1.0;
				edge = 0.0;
				core = 0.0;
			}
			if (local_progress >= 0.999) {
				mask = 0.0;
				edge = 0.0;
				core = 0.0;
			}
		}
	}

	vec3 color = mix(cover_color.rgb, cut_color.rgb, edge);
	color = mix(color, core_gold.rgb, core);
	if (transition_mode == 1) {
		color = mix(
			ring_fill_color.rgb,
			ring_edge_color.rgb,
			edge);
	} else if (transition_mode == 2) {
		float exposure_amount = (
			progress <= 1.0
			? smoothstep(0.0, 0.82, local_progress)
			: 1.0 - smoothstep(
				0.0, 1.0, local_progress)
		);
		float flash_amount = (
			progress <= 1.0
			? smoothstep(0.90, 1.0, local_progress)
			: 1.0 - smoothstep(
				0.0, 0.32, local_progress)
		);
		vec3 exposure_color = energy_exposure_filter(
			screen_color,
			exposure_amount,
			flash_amount);
		color = mix(
			exposure_color,
			ring_edge_color.rgb,
			edge);
	}
	COLOR = vec4(color, max(max(mask, edge), core));
}
