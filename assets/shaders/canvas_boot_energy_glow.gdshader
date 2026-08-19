shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.22, 0.28);
uniform float intensity : hint_range(0.0, 2.0, 0.01) = 0.62;
uniform float radius : hint_range(0.25, 2.0, 0.01) = 0.92;
uniform float pulse_amount : hint_range(0.0, 0.3, 0.01) = 0.06;
uniform float pulse_phase : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec2 pointer_tilt = vec2(0.0);
uniform float pointer_shift : hint_range(0.0, 0.12, 0.005) = 0.05;
uniform float pointer_depth : hint_range(0.0, 0.4, 0.01) = 0.16;

void fragment() {
	vec2 point = (
			(UV - vec2(0.5)) * 2.0
			- pointer_tilt * pointer_shift);
	point *= vec2(
			1.0 + abs(pointer_tilt.y) * pointer_depth,
			1.0 + abs(pointer_tilt.x) * pointer_depth);
	float normalized_distance = length(point) / max(radius, 0.001);
	float halo = exp(-normalized_distance * normalized_distance * 3.6);
	float pulse = 1.0 + sin(pulse_phase * 6.2831853) * pulse_amount;
	float alpha = halo * glow_color.a * intensity * pulse;
	COLOR = vec4(glow_color.rgb * alpha, alpha);
}
