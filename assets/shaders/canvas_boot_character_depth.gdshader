shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 hand_center = vec2(0.82, 0.32);
uniform vec2 hand_radius = vec2(0.27, 0.34);
uniform float blur_texels : hint_range(0.0, 2.0, 0.1) = 1.0;
uniform float blur_mix : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float desaturation : hint_range(0.0, 0.25, 0.01) = 0.06;
uniform vec2 rear_energy_center = vec2(0.3532, 0.2756);
uniform vec2 rear_light_radius = vec2(0.22, 0.30);
uniform vec4 rear_light_color : source_color = vec4(
		0.909804, 0.784314, 0.439216, 1.0);
uniform float rear_light_strength : hint_range(0.0, 0.3, 0.01) = 0.14;
uniform float energy_phase : hint_range(0.0, 1.0, 0.001) = 0.0;

varying vec4 vertex_color;


void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * blur_texels;
	vec4 source = texture(TEXTURE, UV);
	vec4 blurred = (
			source * 2.0
			+ texture(TEXTURE, UV + vec2(texel.x, 0.0))
			+ texture(TEXTURE, UV - vec2(texel.x, 0.0))
			+ texture(TEXTURE, UV + vec2(0.0, texel.y))
			+ texture(TEXTURE, UV - vec2(0.0, texel.y))
		) / 6.0;

	vec2 safe_radius = max(hand_radius, vec2(0.001));
	float ellipse_distance = length((UV - hand_center) / safe_radius);
	float hand_mask = 1.0 - smoothstep(0.78, 1.08, ellipse_distance);
	float foreground_mask = smoothstep(0.62, 0.94, UV.x);
	float depth_mask = hand_mask * foreground_mask;

	vec4 result = mix(
			source,
			blurred,
			depth_mask * clamp(blur_mix, 0.0, 1.0));
	float gray = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	result.rgb = mix(
			result.rgb,
			vec3(gray),
			depth_mask * clamp(desaturation, 0.0, 0.25));

	vec2 safe_light_radius = max(rear_light_radius, vec2(0.001));
	float rear_distance = length(
			(UV - rear_energy_center) / safe_light_radius);
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
	COLOR = result * vertex_color;
}
