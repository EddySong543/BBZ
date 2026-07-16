extends SceneTree

## 内饰花纹清除（美术管线小工具·2026-07-16 导航钮/牌匾去内饰首用）：
##   godot --headless --path . -s tools/img_inner_clear.gd -- <源> <目标> <x> <y> <w> <h> [纸阈=0.72] [守边=5] [扩边=2]
## 用途：Eddy 判资产内饰多余 → 把指定内域矩形里的花纹像素抹成纸面。
## 选区=内域矩形 ∩ 暗色(V<纸阈) ∩ 距外缘(透明/画布边)>守边（双保险不吃外框带），
##      再向外扩 [扩边] 圈（仍限内域∩守边）——连抗锯齿半色调晕和花纹的亮色雕光笔画一起吃掉
##      （亮雕光 V 比纸还高·纯阈值抓不到=首版鬼影教训）。
## 补纸=四向最近纸像素反距离加权 + 微抖动（hash 定值·防大块花纹区补成死平板）。
## 纸阈>1.0=全选模式：矩形内像素无差别全重铺（配 守边0·手画矩形贴花纹用——
##   补纸搜索的"纸"判定始终用 min(纸阈,0.62)，全选模式下不至于找不到纸）。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		print("用法: -- <源> <目标> <x> <y> <w> <h> [纸阈=0.72] [守边=5] [扩边=2]")
		quit(1)
		return
	var src_path := String(args[0])
	var dst_path := String(args[1])
	var rect := Rect2i(int(args[2]), int(args[3]), int(args[4]), int(args[5]))
	var paper_v := float(args[6]) if args.size() > 6 else 0.72
	var guard := int(args[7]) if args.size() > 7 else 5
	var grow := int(args[8]) if args.size() > 8 else 2
	var smooth := int(args[9]) if args.size() > 9 else 0   # 1=补后带内水平 1-2-1 平滑（治宽带逐列内插竖条纹）

	var img := Image.load_from_file(ProjectSettings.globalize_path(src_path))
	if img == null:
		print("读图失败: ", src_path)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	# ── BFS：距"外部"（透明像素/画布边界）的最短步数 ──
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	var queue: Array[Vector2i] = []
	for y in h:
		for x in w:
			var outside := x == 0 or y == 0 or x == w - 1 or y == h - 1
			if img.get_pixel(x, y).a < 0.5:
				outside = true
			if outside:
				dist[y * w + x] = 0
				queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var d0 := dist[p.y * w + p.x]
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + off
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			if dist[q.y * w + q.x] == -1:
				dist[q.y * w + q.x] = d0 + 1
				queue.append(q)

	# ── 选花纹像素：暗芯 → 扩边（吃抗锯齿晕+亮雕光·仍限内域∩守边）──
	var targets: Array[Vector2i] = []
	var is_target := PackedByteArray()
	is_target.resize(w * h)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var c := img.get_pixel(x, y)
			if c.a >= 0.5 and c.v < paper_v and dist[y * w + x] > guard:
				targets.append(Vector2i(x, y))
				is_target[y * w + x] = 1
	for pass_i in grow:
		var added: Array[Vector2i] = []
		for t: Vector2i in targets:
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
					Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var q := t + off
				if not rect.has_point(q) or q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
					continue
				if is_target[q.y * w + q.x] == 1 or dist[q.y * w + q.x] <= guard:
					continue
				if img.get_pixel(q.x, q.y).a < 0.5:
					continue
				is_target[q.y * w + q.x] = 1
				added.append(q)
		targets.append_array(added)

	# ── 补纸：四向最近"纸"（亮·非目标·不透明）反距离加权 + 微抖动 ──
	var search_v := minf(paper_v, 0.62)   # 全选模式（纸阈>1）下搜索仍按 0.62 认纸
	for t: Vector2i in targets:
		var acc := Color(0, 0, 0, 0)
		var wsum := 0.0
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var p := t
			for step in 64:
				p += off
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
					break
				if is_target[p.y * w + p.x] == 1:
					continue
				var c := img.get_pixel(p.x, p.y)
				if c.a >= 0.5 and c.v >= search_v:
					var wt := 1.0 / float(t.distance_to(Vector2(p)))
					acc += c * wt
					wsum += wt
					break
		if wsum <= 0.0:
			continue
		var out := acc / wsum
		# 微抖动（确定性 hash·±1.5% 明度）防大块补丁读作死平板
		var n := float((t.x * 73856093 ^ t.y * 19349663) % 1000) / 1000.0
		var jit := (n - 0.5) * 0.03
		out = Color(clampf(out.r + jit, 0, 1), clampf(out.g + jit, 0, 1), clampf(out.b + jit, 0, 1), 1.0)
		img.set_pixel(t.x, t.y, out)

	# ── 可选：带内水平 1-2-1 平滑（宽带全选重铺时逐列内插会出竖条纹·横向串一遍去相关）──
	if smooth == 1:
		for round_i in 2:
			var buf: Dictionary = {}
			for t: Vector2i in targets:
				var c := img.get_pixel(t.x, t.y) * 2.0
				var wsum := 2.0
				for dx: int in [-1, 1]:
					var q := Vector2i(t.x + dx, t.y)
					if q.x < 0 or q.x >= w:
						continue
					var qc := img.get_pixel(q.x, q.y)
					if qc.a >= 0.5 and qc.v >= 0.55:   # 只混纸面（不把外框暗色晕进来）
						c += qc
						wsum += 1.0
				buf[t] = c / wsum
			for t: Vector2i in buf.keys():
				img.set_pixel(t.x, t.y, buf[t])

	img.save_png(ProjectSettings.globalize_path(dst_path))
	print("OK 内饰清除 %d px | 内域 %s 纸阈 %.2f 守边 %d → %s" % [targets.size(), rect, paper_v, guard, dst_path])
	quit(0)
