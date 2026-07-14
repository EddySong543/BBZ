extends SceneTree
## 轮廓环带换色（美术管线小工具·2026-07-14 导航钮外框对齐悬停框族色首用）：
##   godot --headless --path . -s tools/img_ring_recolor.gd -- <源> <目标> [环深=5] [纸阈=0.62] \
##       [描边hex=140a04] [暗沿hex=1a0e05] [框身hex=221107] [描边阈=0.26] [暗沿阈=0.42]
## 用途：GPT 出图外框颜色不合族 → 只换"贴着透明轮廓的环带"里的深色像素（外框带），
## 纸面（亮度≥纸阈）与环带外的内饰线（回纹/内线）一概不动。
## 选区=几何环带（BFS 距透明轮廓 ≤环深）∩ 暗色（V<纸阈）；映射=按亮度三档（描边/暗沿/框身）。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("用法: -- <源> <目标> [环深=5] [纸阈=0.62] [描边hex] [暗沿hex] [框身hex] [描边阈=0.26] [暗沿阈=0.42]")
		quit(1)
		return
	var ring := int(a[2]) if a.size() > 2 else 5
	var v_paper := float(a[3]) if a.size() > 3 else 0.62
	var c_contour := Color(String(a[4])) if a.size() > 4 else Color("140a04")
	var c_edge := Color(String(a[5])) if a.size() > 5 else Color("1a0e05")
	var c_band := Color(String(a[6])) if a.size() > 6 else Color("221107")
	var th_contour := float(a[7]) if a.size() > 7 else 0.26
	var th_edge := float(a[8]) if a.size() > 8 else 0.42
	var img := Image.load_from_file(ProjectSettings.globalize_path(String(a[0])))
	if img == null:
		print("FAIL 载入失败: ", a[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	# BFS：距透明轮廓的四邻距离
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(9999)
	var queue: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 \
					or img.get_pixel(x - 1, y).a < 0.5 or img.get_pixel(x + 1, y).a < 0.5 \
					or img.get_pixel(x, y - 1).a < 0.5 or img.get_pixel(x, y + 1).a < 0.5:
				dist[y * w + x] = 0
				queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var d: int = dist[p.y * w + p.x]
		if d >= ring:
			continue
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + off
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			if img.get_pixel(q.x, q.y).a < 0.5:
				continue
			if dist[q.y * w + q.x] > d + 1:
				dist[q.y * w + q.x] = d + 1
				queue.append(q)
	var n := 0
	for y in h:
		for x in w:
			if dist[y * w + x] > ring:
				continue
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var v := maxf(c.r, maxf(c.g, c.b))
			if v >= v_paper:
				continue
			var out: Color = c_contour if v < th_contour else (c_edge if v < th_edge else c_band)
			img.set_pixel(x, y, Color(out.r, out.g, out.b, c.a))
			n += 1
	img.save_png(ProjectSettings.globalize_path(String(a[1])))
	print("OK 环带换色 %d px | 环深 %d 纸阈 %.2f → %s" % [n, ring, v_paper, a[1]])
	quit()
