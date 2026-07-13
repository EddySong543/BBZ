extends SceneTree
## 实色底+泛光 → 透明（美术管线小工具·2026-07-13）：
##   godot --headless --path . -s tools/img_bg_flood_to_alpha.gd -- <源> <目标> [邻差阈=0.055]
## 适用：GPT 出图把"透明底"画成实色灰底+主体周围柔和泛光（非棋盘格·img_checker_to_alpha 吃不动）。
## 原理：从图像四边全部边框像素做 BFS 泛洪清透明——渐变缓慢（邻差小）持续蔓延，
## 撞到主体硬轮廓（像素画边界=色值跳变大）即停。⚠ 主体内部若有与背景连通的开口会漏进去——
## 本工具只适合闭合轮廓资产（UI 板/横幅类）。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("用法: -- <源> <目标> [邻差阈=0.055]")
		quit()
		return
	var tol := 0.055 if args.size() < 3 else float(args[2])
	var img := Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	if img == null:
		print("FAIL 载入失败: ", args[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var cleared := PackedByteArray()
	cleared.resize(w * h)
	var queue: Array[Vector2i] = []
	for x in w:   # 四边全边框做种子
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in h:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
	var n := 0
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		var idx := p.y * w + p.x
		if cleared[idx] == 1:
			continue
		cleared[idx] = 1
		n += 1
		var c := img.get_pixelv(p)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + d
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			if cleared[q.y * w + q.x] == 1:
				continue
			var cq := img.get_pixelv(q)
			if absf(cq.r - c.r) < tol and absf(cq.g - c.g) < tol and absf(cq.b - c.b) < tol:
				queue.append(q)
	for y in h:   # 清透明
		for x in w:
			if cleared[y * w + x] == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	img.save_png(ProjectSettings.globalize_path(args[1]))
	print("OK %s → %s | 泛洪清背景 %d px（阈 %.3f）" % [args[0], args[1], n, tol])
	quit()
