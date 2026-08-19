shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 sun_center = vec2(0.84, 0.19);
uniform float aspect_ratio : hint_range(1.0, 2.5, 0.001) = 1.777778;
uniform float core_radius : hint_range(0.005, 0.12, 0.001) = 0.058;
uniform float inner_halo_radius : hint_range(0.02, 0.3, 0.001) = 0.19;
uniform float outer_halo_radius : hint_range(0.05, 0.5, 0.001) = 0.42;
uniform vec4 core_color : source_color = vec4(1.0, 0.78, 0.58, 1.0);
uniform vec4 halo_color : source_color = vec4(0.98, 0.65, 0.45, 1.0);
uniform float core_opacity : hint_range(0.0, 1.0, 0.01) = 0.56;
uniform float halo_strength : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float breath_cycle_sec : hint_range(3.0, 16.0, 0.1) = 8.4;
uniform float breath_amount : hint_range(0.0, 0.12, 0.005) = 0.035;
uniform vec2 pixel_grid = vec2(480.0, 270.0);


void fragment() {
	vec2 snapped_uv = floor(UV * pixel_grid + 0.5) / pixel_grid;
	vec2 delta = snapped_uv - sun_center;
	delta.x *= aspect_ratio;
	float breath = sin(TIME * TAU / max(breath_cycle_sec, 0.001));
	float distance_to_sun = length(delta) / (1.0 + breath * breath_amount);

	float core = 1.0 - smoothstep(
			core_radius - 0.018,
			core_radius + 0.022,
			distance_to_sun);
	float inner_halo = 1.0 - smoothstep(
			core_radius,
			inner_halo_radius,
			distance_to_sun);
	float outer_halo = 1.0 - smoothstep(
			inner_halo_radius,
			outer_halo_radius,
			distance_to_sun);
	inner_halo *= inner_halo;
	outer_halo *= outer_halo * 0.28;

	core *= core_opacity;
	float halo_alpha = (
			inner_halo * 0.46 + outer_halo) * halo_strength;
	float glow_alpha = clamp(core + halo_alpha, 0.0, 1.0);
	float core_mix = core / max(core + halo_alpha, 0.001);
	vec3 glow_rgb = mix(
			halo_color.rgb,
			core_color.rgb,
			clamp(core_mix, 0.0, 1.0));
	COLOR = vec4(glow_rgb, glow_alpha);
}
