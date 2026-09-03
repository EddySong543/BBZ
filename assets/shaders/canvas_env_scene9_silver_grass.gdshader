shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 root_shadow : source_color = vec4(0.50, 0.59, 0.60, 1.0);
uniform vec4 silver_mid : source_color = vec4(0.66, 0.73, 0.72, 1.0);
uniform vec4 silver_tip : source_color = vec4(0.83, 0.87, 0.84, 1.0);
uniform vec4 cool_highlight : source_color = vec4(0.90, 0.92, 0.88, 1.0);
uniform vec2 source_grid = vec2(72.0, 40.0);
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_speed : hint_range(0.0, 4.0, 0.01) = 0.72;
uniform float wind_fps : hint_range(1.0, 16.0, 1.0) = 8.0;
uniform float wind_strength : hint_range(0.0, 6.0, 1.0) = 2.0;
uniform float tip_lift : hint_range(0.0, 4.0, 1.0) = 1.0;
uniform float original_color_influence : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float root_fade_start : hint_range(0.5, 1.0, 0.01) = 0.98;

varying float instance_depth;
varying float palette_variation;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.28318530718;
	float wind_tick = floor(TIME * wind_fps) / wind_fps;
	float gust = floor(sin(wind_tick * wind_speed * 3.0 + phase) * 1.5 + 0.5);
	float tip_mask = step(UV.y, 0.38);
	VERTEX.x += wind_direction.x * gust * wind_strength * tip_mask;
	VERTEX.y -= abs(gust) * tip_lift * tip_mask;
	instance_depth = INSTANCE_CUSTOM.z;
	palette_variation = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec2 sample_uv = (floor(UV * source_grid) + vec2(0.5)) / source_grid;
	vec4 source = texture(TEXTURE, sample_uv);
	float hard_alpha = step(alpha_cutoff, source.a)
		* (1.0 - step(root_fade_start, UV.y));
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 silver = root_shadow.rgb;
	silver = mix(silver, silver_mid.rgb, step(0.32, luminance));
	silver = mix(silver, silver_tip.rgb, step(0.61, luminance));
	silver = mix(silver, cool_highlight.rgb,
		step(0.82 - palette_variation * 0.04, luminance));
	float depth_level = floor(instance_depth * 3.0 + 0.5) / 3.0;
	float depth_light = mix(0.82, 1.0, depth_level);
	COLOR = vec4(silver * depth_light, hard_alpha);
}
