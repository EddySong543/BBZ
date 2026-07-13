extends SceneTree
## 9-slice 中段行亮度拉平（美术管线小工具·2026-07-13 导航钮纵向平铺百叶窗根修）：
##   godot --headless --path . -s tools/img_flatten_rows.gd -- <源> <目标> <边距px>
## 对内部区（x/y 均在边距内侧）逐行求平均亮度，整行乘性归一到内部总平均——
## 消掉中段的纵向渐变（平铺无接缝），颗粒纹理保留；四边边带（角/描边/高光线）不动。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		print("用法: -- <源> <目标> <边距px>")
		quit()
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	if img == null:
		print("FAIL 载入失败: ", args[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var m := int(args[2])
	var w := img.get_width()
	var h := img.get_height()
	# 逐行内部平均（RGB 逐通道·亮度+色相漂移一起拉平）
	var row_means: Array[Vector3] = []
	var total := Vector3.ZERO
	for y in range(m, h - m):
		var s := Vector3.ZERO
		for x in range(m, w - m):
			var c := img.get_pixel(x, y)
			s += Vector3(c.r, c.g, c.b)
		var mean := s / float(w - m * 2)
		row_means.append(mean)
		total += mean
	var target := total / float(row_means.size())
	# 整行逐通道乘性归一（只动内部区·防 0 除）
	for y in range(m, h - m):
		var rm := row_means[y - m]
		var k := Vector3(target.x / maxf(rm.x, 0.001),
			target.y / maxf(rm.y, 0.001), target.z / maxf(rm.z, 0.001))
		for x in range(m, w - m):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * k.x, c.g * k.y, c.b * k.z, c.a))
	img.save_png(ProjectSettings.globalize_path(args[1]))
	print("OK %s → %s | 内部 %d 行逐通道归一到 (%.3f, %.3f, %.3f)" % [
		args[0], args[1], h - m * 2, target.x, target.y, target.z])
	quit()
