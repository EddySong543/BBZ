shader_type canvas_item;

// 搜索彩蛋猫猫头统一染成图鉴关闭键/搜索图标的深咖墨色。
// 只保留原图透明度与少量明暗层次，不把原素材的棕色色相带入书页。
uniform vec4 ink_color : source_color = vec4(0.290196, 0.227451, 0.176471, 1.0);
uniform float detail_strength : hint_range(0.0, 0.25) = 0.12;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float source_luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float detail = mix(1.0, clamp(source_luma / 0.19, 0.78, 1.18), detail_strength);
	COLOR = vec4(ink_color.rgb * detail, source.a * ink_color.a);
}
