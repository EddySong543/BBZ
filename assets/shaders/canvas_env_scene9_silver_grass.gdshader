shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 root_shadow : source_color = vec4(0.55, 0.61, 0.61, 1.0);
uniform vec4 silver_mid : source_color = vec4(0.67, 0.72, 0.71, 1.0);
uniform vec4 silver_tip : source_color = vec4(0.84, 0.87, 0.85, 1.0);
uniform vec4 cool_highlight : source_color = vec4(0.80, 0.85, 0.88, 1.0);
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_speed : hint_range(0.0, 4.0, 0.01) = 0.72;
uniform float wind_strength : hint_range(0.0, 30.0, 0.1) = 10.0;
uniform float tip_lift : hint_range(0.0, 12.0, 0.1) = 2.4;
uniform float original_color_influence : hint_range(0.0, 1.0, 0.01) = 0.04;
uniform float alpha_cutoff : hint_range(0.0, 0.5, 0.005) = 0.025;
uniform float root_fade_start : hint_range(0.5, 1.0, 0.01) = 0.96;

varying float instance_depth;
varying float palette_variation;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.28318530718;
	float amplitude = mix(0.72, 1.12, INSTANCE_CUSTOM.y);
	float broad_gust = sin(TIME * wind_speed + phase);
	float fine_gust = sin(TIME * wind_speed * 1.73 + phase * 2.37) * 0.32;
	float tip_mask = pow(clamp(1.0 - UV.y, 0.0, 1.0), 2.15);
	VERTEX.x += wind_direction.x * (broad_gust + fine_gust)
		* wind_strength * amplitude * tip_mask;
	VERTEX.y -= abs(broad_gust) * tip_lift * tip_mask;
	instance_depth = INSTANCE_CUSTOM.z;
	palette_variation = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a < alpha_cutoff) {
		discard;
	}
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float height_mask = pow(clamp(1.0 - UV.y, 0.0, 1.0), 0.72);
	vec3 silver = mix(root_shadow.rgb, silver_mid.rgb,
		smoothstep(0.08, 0.58, luminance));
	silver = mix(silver, silver_tip.rgb,
		smoothstep(0.48, 0.94, luminance) * mix(0.52, 1.0, height_mask));
	silver = mix(silver, cool_highlight.rgb,
		clamp(height_mask * (0.08 + palette_variation * 0.10), 0.0, 0.18));
	silver = mix(silver, source.rgb, original_color_influence);
	float depth_fade = mix(0.78, 1.0, instance_depth);
	float root_fade = 1.0 - smoothstep(root_fade_start, 0.995, UV.y);
	COLOR = vec4(silver * depth_fade, source.a * root_fade);
}
