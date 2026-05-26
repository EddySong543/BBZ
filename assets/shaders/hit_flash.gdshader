shader_type canvas_item;

// 受击白闪 shader —— 把贴图 RGB 朝 flash_color 混合，保留原 alpha。
// flash_amount 由代码 tween 1.0 → 0.0 做一次闪白（标准 hit-flash 写法）。
// 用于 CharacterDisplay 的 flash_white()。

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR.rgb = mix(tex.rgb, flash_color.rgb, flash_amount);
	COLOR.a = tex.a;
}
