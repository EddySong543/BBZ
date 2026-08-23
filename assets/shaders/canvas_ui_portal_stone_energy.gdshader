shader_type canvas_item;
render_mode unshaded;

uniform vec4 energy_color : source_color = vec4(1.0, 0.76, 0.24, 1.0);
uniform vec4 impact_color : source_color = vec4(0.45, 0.86, 0.77, 1.0);
uniform float energy_mix : hint_range(0.0, 1.0) = 0.0;
uniform float energy_threshold : hint_range(0.0, 1.0) = 0.58;
uniform float energy_phase = 0.0;
uniform float activation_flash : hint_range(0.0, 1.0) = 0.0;
uniform float impact_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float anim_time = 0.0;


float hash21(vec2 value) {
	value = fract(value * vec2(127.1, 311.7));
	value += dot(value, value + 34.5);
	return fract(value.x * value.y);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float high_channel = max(source.r, max(source.g, source.b));
	float low_channel = min(source.r, min(source.g, source.b));
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float neutral_mask = 1.0 - smoothstep(0.12, 0.34, high_channel - low_channel);
	float bright_mask = smoothstep(energy_threshold, 0.94, luminance);
	float energy_mask = bright_mask * mix(0.38, 1.0, neutral_mask);

	// 两组速度不同的上行能量带，避免整颗晶体同时做机械式明暗呼吸。
	float rising_a = 0.5 + 0.5 * sin(
			(1.0 - UV.y) * 34.0 - anim_time * 6.2 + energy_phase
			+ sin(UV.x * 17.0 + energy_phase) * 0.8);
	float rising_b = 0.5 + 0.5 * sin(
			(1.0 - UV.y) * 19.0 - anim_time * 3.7 + UV.x * 7.0
			+ energy_phase * 1.9);
	float flow = smoothstep(0.52, 0.92, rising_a) * 0.72 + rising_b * 0.28;

	// 闪点固定在素材像素格上，但按不规则时间窗启灭，不产生连续塑料高光。
	vec2 source_pixel = floor(UV / max(TEXTURE_PIXEL_SIZE * 3.0, vec2(0.0001)));
	float spark_seed = hash21(source_pixel + vec2(energy_phase * 11.0));
	float spark_clock = 0.5 + 0.5 * sin(
			anim_time * mix(4.1, 7.3, spark_seed) + spark_seed * 31.0);
	float spark = step(0.965, spark_seed) * smoothstep(0.82, 0.98, spark_clock);

	float core_pulse = 0.92 + sin(anim_time * 2.1 + energy_phase) * 0.06
			+ sin(anim_time * 5.4 + energy_phase * 2.3) * 0.02;
	float connected = smoothstep(0.985, 1.0, energy_mix);
	float connected_flicker = 0.84
			+ sin(anim_time * 3.15 + energy_phase) * 0.11
			+ sin(anim_time * 7.70 + energy_phase * 2.6) * 0.05;
	vec3 charged_core = mix(vec3(1.0), energy_color.rgb, 0.72)
			* mix(0.78, 1.28, luminance) * core_pulse
			* mix(1.0, connected_flicker, connected);
	float charged_amount = energy_mask * energy_mix;
	// 未连接时也明确收束成白色阵眼；energy_mix 只代表模式色连接进度。
	vec3 idle_white = vec3(mix(luminance, 1.0, 0.62));
	vec3 result = mix(source.rgb, idle_white, energy_mask * (1.0 - energy_mix) * 0.58);
	result = mix(result, charged_core,
			charged_amount * mix(0.52, 0.96, flow));
	result += energy_color.rgb * charged_amount * (flow * 0.22 + spark * 0.52);
	result += energy_color.rgb * energy_mask * connected
			* max(connected_flicker - 0.86, 0.0) * 0.48;
	result = mix(result, vec3(1.0), energy_mask * activation_flash * 0.42);
	// 撞击只激起模式色能量纹，不再把整颗石头闪成白色。
	float impact_wave = 0.5 + 0.5 * sin((UV.y + UV.x * 0.34) * 28.0
			- anim_time * 12.0 + energy_phase);
	result += impact_color.rgb * energy_mask * impact_pulse
			* (0.18 + smoothstep(0.60, 0.92, impact_wave) * 0.42);
	COLOR = vec4(result, source.a);
}
