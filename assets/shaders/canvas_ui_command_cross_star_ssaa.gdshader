shader_type canvas_item;
render_mode unshaded;

uniform vec2 star_center = vec2(33.5, 64.5);
uniform vec2 star_radii = vec2(14.0, 13.0);
uniform float profile_power : hint_range(2.0, 6.0, 0.1) = 5.0;
uniform vec4 star_color : source_color = vec4(0.949, 0.910, 0.800, 1.0);
uniform vec2 shadow_offset = vec2(1.0, 2.0);
uniform float shadow_expand : hint_range(0.0, 4.0, 0.25) = 1.0;
uniform vec4 shadow_color : source_color = vec4(0.02, 0.012, 0.008, 0.52);

varying vec2 local_point;


void vertex() {
	local_point = VERTEX;
}


float inside_star(vec2 point, vec2 center, vec2 radii, float power) {
	vec2 normalized = abs(point - center) / max(radii, vec2(0.001));
	float exponent = 2.0 / max(power, 0.001);
	float metric = pow(normalized.x, exponent) + pow(normalized.y, exponent);
	return 1.0 - step(1.0, metric);
}


float supersampled_coverage(vec2 point, vec2 center, vec2 radii, float power) {
	// 每个最终屏幕像素取 9×9 个真实面积样本。奇数网格包含像素轴心，能够
	// 保留深收腰四尖星的亚像素尖端。fwidth(local_point) 会随
	// Canvas Items 的目标分辨率变化，因此编辑器缩放和 F6 都重新栅格化同一曲线，
	// 不会把 1920×1080 的像素块当作贴图再次放大。
	vec2 footprint = max(fwidth(local_point), vec2(0.0001));
	float covered = 0.0;
	for (int sample_y = 0; sample_y < 9; sample_y++) {
		for (int sample_x = 0; sample_x < 9; sample_x++) {
			vec2 unit_offset = (vec2(float(sample_x), float(sample_y)) + 0.5)
					/ 9.0 - 0.5;
			covered += inside_star(
					point + unit_offset * footprint,
					center, radii, power);
		}
	}
	return covered / 81.0;
}


void fragment() {
	float shadow_coverage = supersampled_coverage(
			local_point,
			star_center + shadow_offset,
			star_radii + vec2(shadow_expand),
			profile_power);
	float main_coverage = supersampled_coverage(
			local_point, star_center, star_radii, profile_power);
	vec4 shadow_layer = vec4(
			shadow_color.rgb, shadow_color.a * shadow_coverage);
	vec4 main_layer = vec4(star_color.rgb, star_color.a * main_coverage);
	float output_alpha = main_layer.a + shadow_layer.a * (1.0 - main_layer.a);
	vec3 output_rgb = (
			main_layer.rgb * main_layer.a
			+ shadow_layer.rgb * shadow_layer.a * (1.0 - main_layer.a)
		) / max(output_alpha, 0.0001);
	COLOR = vec4(output_rgb, output_alpha);
}
