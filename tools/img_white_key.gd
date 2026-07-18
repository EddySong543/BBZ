extends SceneTree
## 白底键控+内容裁切（美术管线小工具·GPT「假透明」棋盘救治）：把「高亮度+低饱和」像素
## （烤死在图里的棋盘白/灰底·alpha=255）转全透明，再按非透明内容包围盒裁切存出。
## 饱和度键=通道极差（max-min）→ 粉花/亮草等有色高光不受伤，只吃中性白灰。
##   godot --headless --path . -s tools/img_white_key.gd -- <源路径> <目标路径> [亮度阈=0.90] [极差阈=0.06]
## 用途：scene2 ground 首例（2026-07-18·GPT 出图透明底偶发烤成棋盘格时的通用救治）。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("用法: -- <源> <目标> [亮度阈] [极差阈]")
		quit(1)
		return
	var lum_thr := float(a[2]) if a.size() > 2 else 0.90
	var sat_thr := float(a[3]) if a.size() > 3 else 0.06
	var img := Image.load_from_file(ProjectSettings.globalize_path(String(a[0])))
	if img == null:
		print("FAIL 载入失败: ", a[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var keyed := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if lum > lum_thr and (mx - mn) < sat_thr:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				keyed += 1
	var rect := img.get_used_rect()
	var out := img.get_region(rect)
	out.save_png(ProjectSettings.globalize_path(String(a[1])))
	print("OK %s → %s 键控 %d px·裁切 %s → %dx%d" %
		[a[0], a[1], keyed, rect, out.get_width(), out.get_height()])
	quit()
