shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 left_glow_region = vec4(0.16, 0.39, 0.42, 0.80);
uniform vec4 right_glow_region = vec4(0.58, 0.36, 0.86, 0.79);
uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.18, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.22;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.72;

float inside_region(vec2 uv, vec4 region) {
	vec2 lower = step(region.xy, uv);
	vec2 upper = step(uv, region.zw);
	return lower.x * lower.y * upper.x * upper.y;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float region_mask = max(
		inside_region(UV, left_glow_region),
		inside_region(UV, right_glow_region)
	);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float warm_bias = max(source.r - source.b, 0.0);
	float source_mask = smoothstep(0.42, 0.82, luminance + warm_bias * 0.40);
	float pulse = 0.90 + 0.10 * sin(TIME * pulse_speed + UV.x * 9.0);
	float alpha = source.a * region_mask * source_mask * glow_strength * pulse;
	COLOR = vec4(glow_color.rgb * alpha, alpha);
}
