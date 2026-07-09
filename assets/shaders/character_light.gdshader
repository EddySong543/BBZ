shader_type canvas_item;

// =============================================================
// character_light.gdshader
// 作者: Claude (Game Studios) ｜ 用途: 角色精灵的环境光照（CharacterDisplay 用）
//   让角色"接受月光"，融入夜色逆光环境：
//     1) 方向性背光：朝月一侧保留本色(受光)，背月一侧压暗+染冷(阴影) → 立体逆光感。
//     2) 月光边缘光 rim：朝月轮廓勾一道冷蓝亮边(月光描边)。
//     3) 受击白闪 flash：保留原 hit_flash 功能(flash_amount 由代码 tween)。
//   light_dir = 朝月方向(UV 空间，y 负=屏幕上方)；CharacterDisplay 按 flip_h 翻转其 x。
// 目标平台: PC (Windows D3D12 / Forward+)。复杂度: 1 次额外纹理采样(rim) → 极低。
// 渲染管线: Godot 4.6 Forward+（2D canvas_item，作用于 SubViewport 内的 AnimatedSprite2D）。
// =============================================================

group_uniforms flash;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;              // 受击白闪(代码 tween 1→0)
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
group_uniforms;

group_uniforms backlight;  // 方向性背光
uniform vec2 light_dir = vec2(0.6, -0.6);                            // 朝月方向(UV 空间)
uniform float backlight : hint_range(0.0, 1.0) = 0.25;              // 背光强度(背月侧压暗程度)
uniform vec4 shadow_tint : source_color = vec4(0.45, 0.55, 0.80, 1.0); // 背光阴影色(冷)
group_uniforms;

group_uniforms ambient;  // 暖补偿：抵消全屏 PostFX 冷滤镜对皮肤的染色（角色专属，不波及背景）
uniform vec4 skin_warmth : source_color = vec4(1.08, 1.0, 0.9, 1.0);
uniform float warmth_amount : hint_range(0.0, 1.0) = 0.3;
group_uniforms;

group_uniforms rim;  // 月光边缘光
uniform vec4 rim_color : source_color = vec4(0.62, 0.78, 1.0, 1.0); // 月光描边色(冷蓝白)
uniform float rim_strength : hint_range(0.0, 2.0) = 0.5;
uniform float rim_width : hint_range(1.0, 8.0) = 3.0;               // 边缘检测宽度(纹理像素)
group_uniforms;

group_uniforms fill;  // 月光补光：加法托亮整体（暗色立绘融进夜色的解药），默认 0 = 行为不变
uniform vec4 fill_color : source_color = vec4(0.62, 0.78, 1.0, 1.0); // 补光色(与月光同源冷蓝)
uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;             // 补光强度(0=关闭)
group_uniforms;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;
	float a = tex.a;

	vec2 ld = normalize(light_dir);

	// 1) 方向性背光：朝月侧(ld 方向)受光保留本色、背月侧压暗染冷
	float lit = dot(UV - vec2(0.5), ld);          // 朝月>0 / 背月<0
	float shade = smoothstep(-0.35, 0.35, lit);   // 0(背月,暗) → 1(朝月,亮)
	vec3 shaded = mix(col * shadow_tint.rgb, col, shade);
	col = mix(col, shaded, backlight);

	// 1.5) 暖补偿：抵消全屏冷滤镜，让皮肤回正（在 rim 之前，不影响月光边）
	col = mix(col, col * skin_warmth.rgb, warmth_amount);

	// 1.6) 月光补光：加法托亮(乘法对近黑像素无力)。朝月侧略强，且按亮度反削
	//     (1-lum×0.7) 保护脸部等亮部不过曝——只把暗部从背景里托出来。
	float fill_w = 0.65 + 0.35 * shade;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col += fill_color.rgb * fill_amount * fill_w * (1.0 - lum * 0.7);

	// 2) 月光边缘光 rim：朝月外移一截若已透明 → 当前像素是"朝月的轮廓"
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;
	float a_out = texture(TEXTURE, UV + ld * px).a;
	float rim = clamp(a - a_out, 0.0, 1.0);
	col += rim_color.rgb * rim * rim_strength;

	// 3) 受击白闪
	col = mix(col, flash_color.rgb, flash_amount);

	COLOR = vec4(col, a) * COLOR;  // 末尾乘顶点色，保留 modulate
}
