extends SceneTree
## 图片精准单色系换色（美术管线小工具）：把资产按亮度映射到目标色系——
## out = 目标色 × (像素亮度 / 参考亮度)，alpha 原样保留。
## 亮部（如暖骨带）≈目标色本色·暗部（描边/回纹）=目标色深档 → 结构/明暗全保留，只换色相。
##   godot --headless --path . -s tools/img_recolor.gd -- <源路径> <目标路径> <目标色hex如 D4A94E> [参考亮度=0.86]
## 用途：头像框复用为道具三阶框（蓝/紫/金）/敌方赤框等色变体。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		print("用法: -- <源> <目标> <hex> [参考亮度]")
		quit(1)
		return
	var target := Color.from_string("#" + String(a[2]).lstrip("#"), Color.MAGENTA)
	var ref_lum := float(a[3]) if a.size() > 3 else 0.86
	var img := Image.load_from_file(ProjectSettings.globalize_path(String(a[0])))
	if img == null:
		print("FAIL 载入失败: ", a[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var k := clampf(lum / ref_lum, 0.0, 1.25)   # 亮部微超参考=留高光呼吸
			img.set_pixel(x, y, Color(
				clampf(target.r * k, 0.0, 1.0),
				clampf(target.g * k, 0.0, 1.0),
				clampf(target.b * k, 0.0, 1.0), c.a))
	img.save_png(ProjectSettings.globalize_path(String(a[1])))
	print("OK %s → %s 换色 #%s (参考亮度 %.2f)" % [a[0], a[1], a[2], ref_lum])
	quit()
