extends SceneTree
## 棋盘格假透明转真透明（美术管线小工具）：把「GPT 把透明底画成白灰棋盘格贴纸」的图，
## 按【低饱和+高明度=中性亮色】判定整图转透明——治 img_band_white_to_alpha（判白 0.95）吃不掉浅灰格的场景。
##   godot --headless --path . -s tools/img_checker_to_alpha.gd -- <源res路径> <目标res路径> [明度阈=0.70] [饱和阈=0.08]
## 判定：max(r,g,b) >= 明度阈 且 (max-min) <= 饱和阈 → 透明。
## 不误伤：纸面暖黄/金帽（高饱和）、木轴深褐/墨描边（低明度）都不满足条件。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("用法: -- <源> <目标> [明度阈=0.70] [饱和阈=0.08]")
		quit(1)
		return
	var src := String(a[0])
	var dst := String(a[1])
	var val_th := float(a[2]) if a.size() > 2 else 0.70
	var sat_th := float(a[3]) if a.size() > 3 else 0.08
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		print("FAIL 载入失败: ", src)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var hi := maxf(c.r, maxf(c.g, c.b))
			var lo := minf(c.r, minf(c.g, c.b))
			if hi >= val_th and (hi - lo) <= sat_th:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				n += 1
	img.save_png(ProjectSettings.globalize_path(dst))
	# 处理后内容包围盒 + 中列/中行不透明跨度（排版对位用）
	var r := img.get_used_rect()
	var cx := img.get_width() / 2
	var top := -1
	var bottom := -1
	for y in img.get_height():
		if img.get_pixel(cx, y).a > 0.02:
			if top < 0:
				top = y
			bottom = y
	var cy := img.get_height() / 2
	var left := -1
	var right := -1
	for x in img.get_width():
		if img.get_pixel(x, cy).a > 0.02:
			if left < 0:
				left = x
			right = x
	print("OK %s → %s | 转透明 %d px | 内容 %s | 中列不透明 y%d-%d | 中行不透明 x%d-%d" % [
		src, dst, n, r, top, bottom, left, right])
	quit()
