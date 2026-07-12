extends SceneTree
## 带区白转透明（美术管线小工具）：把图片顶/底带区内的近白像素改成透明——
## 治「GPT 把留白画成实心白边」（透明底没真给）的补救。
##   godot --headless --path . -s tools/img_band_white_to_alpha.gd -- <源res路径> <目标res路径> <顶带高px> <底带起y> [阈值=0.95]
## 判白：min(r,g,b) >= 阈值（纸面是暖tan、木轴是深褐、金端头高光偏黄——都不会误伤）。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		print("用法: -- <源> <目标> <顶带高> <底带起y> [阈值]")
		quit(1)
		return
	var src := String(a[0])
	var dst := String(a[1])
	var top_h := int(a[2])
	var bottom_y := int(a[3])
	var th := float(a[4]) if a.size() > 4 else 0.95
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		print("FAIL 载入失败: ", src)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var n_top := 0
	var n_bot := 0
	for y in img.get_height():
		if y >= top_h and y < bottom_y:
			continue
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and minf(c.r, minf(c.g, c.b)) >= th:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				if y < top_h:
					n_top += 1
				else:
					n_bot += 1
	img.save_png(ProjectSettings.globalize_path(dst))
	# 处理后中列不透明范围（=纸面纵向实际跨度·排版用）
	var cx := img.get_width() / 2
	var top := -1
	var bottom := -1
	for y in img.get_height():
		if img.get_pixel(cx, y).a > 0.02:
			if top < 0:
				top = y
			bottom = y
	print("OK %s → %s | 顶带转透明 %d px·底带 %d px | 中列不透明 y%d-%d" % [src, dst, n_top, n_bot, top, bottom])
	quit()
