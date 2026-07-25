shader_type canvas_item;
render_mode unshaded;

// Scene1 foliage depth grade. A zero blur keeps the authored sprite crisp;
// positive values use alpha-weighted discrete samples for atmospheric depth
// without bleeding transparent black into the silhouette.
uniform vec4 night_tint : source_color = vec4(0.34, 0.48, 0.72, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.58;
uniform float saturation : hint_range(0.0, 1.0) = 0.48;
uniform float brightness : hint_range(0.0, 1.5) = 0.72;
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.92;
uniform float blur_amount : hint_range(0.0, 4.0, 0.1) = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.075, 0.105, 0.19, 1.0);
uniform float shadow_lift : hint_range(0.0, 1.0) = 0.22;
uniform vec4 rim_tint : source_color = vec4(0.46, 0.66, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_side : hint_range(-1.0, 1.0, 1.0) = 1.0;
uniform float rim_width : hint_range(1.0, 4.0, 1.0) = 2.0;
// Some generated far-grove PNGs contain a baked white/light-gray checkerboard.
// Keep this disabled for authored alpha sprites and enable it only on those
// dedicated far-grove materials.
uniform float background_key_strength : hint_range(0.0, 1.0) = 0.0;
uniform float background_key_luma_min : hint_range(0.0, 1.0) = 0.86;
uniform float background_key_luma_max : hint_range(0.0, 1.0) = 0.95;
uniform float background_key_chroma_max : hint_range(0.01, 0.25) = 0.08;

vec4 key_baked_background(vec4 sample_color) {
	float hi = max(max(sample_color.r, sample_color.g), sample_color.b);
	float lo = min(min(sample_color.r, sample_color.g), sample_color.b);
	float chroma = hi - lo;
	float luma = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
	float bright_neutral = smoothstep(background_key_luma_min,
			background_key_luma_max, luma);
	bright_neutral *= 1.0 - smoothstep(background_key_chroma_max * 0.5,
			background_key_chroma_max, chroma);
	sample_color.a *= 1.0 - bright_neutral * background_key_strength;
	return sample_color;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 s0 = key_baked_background(texture(TEXTURE, UV));
	vec4 sxp = key_baked_background(texture(TEXTURE, UV + vec2(px.x, 0.0)));
	vec4 sxn = key_baked_background(texture(TEXTURE, UV - vec2(px.x, 0.0)));
	vec4 syp = key_baked_background(texture(TEXTURE, UV + vec2(0.0, px.y)));
	vec4 syn = key_baked_background(texture(TEXTURE, UV - vec2(0.0, px.y)));
	vec4 spp = key_baked_background(texture(TEXTURE, UV + px));
	vec4 snn = key_baked_background(texture(TEXTURE, UV - px));
	vec4 spn = key_baked_background(texture(TEXTURE, UV + vec2(px.x, -px.y)));
	vec4 snp = key_baked_background(texture(TEXTURE, UV + vec2(-px.x, px.y)));

	float alpha_sum = s0.a * 0.25;
	alpha_sum += (sxp.a + sxn.a + syp.a + syn.a) * 0.125;
	alpha_sum += (spp.a + snn.a + spn.a + snp.a) * 0.0625;
	vec3 premul_rgb = s0.rgb * s0.a * 0.25;
	premul_rgb += (sxp.rgb * sxp.a + sxn.rgb * sxn.a
			+ syp.rgb * syp.a + syn.rgb * syn.a) * 0.125;
	premul_rgb += (spp.rgb * spp.a + snn.rgb * snn.a
			+ spn.rgb * spn.a + snp.rgb * snp.a) * 0.0625;
	vec4 tex = vec4(premul_rgb / max(alpha_sum, 0.0001), alpha_sum);

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(vec3(luma), tex.rgb, saturation);
	vec3 moonlit = mix(muted, muted * night_tint.rgb, tint_strength);
	float shadow_mask = (1.0 - smoothstep(0.08, 0.46, luma)) * shadow_lift;
	moonlit = mix(moonlit, shadow_tint.rgb, shadow_mask);

	float rim_neighbor = key_baked_background(texture(TEXTURE,
			UV + vec2(rim_side * TEXTURE_PIXEL_SIZE.x * rim_width, 0.0))).a;
	float rim_edge = max(s0.a - rim_neighbor, 0.0);
	moonlit += rim_tint.rgb * rim_edge * rim_strength;

	COLOR = vec4(clamp(moonlit * brightness, vec3(0.0), vec3(1.0)),
			tex.a * alpha_scale);
}
