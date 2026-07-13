extends SceneTree
## 图片 NEAREST 缩放（美术管线小工具）：像素资产降采样/规格化到精准目标尺寸。
##   godot --headless --path . -s tools/img_resize.gd -- <源路径> <目标路径> <宽> <高>
## 路径可为 res:// 或绝对盘符路径。恒 NEAREST（保像素硬边·不糊）。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		print("用法: -- <源> <目标> <宽> <高>")
		quit(1)
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(String(a[0])))
	if img == null:
		print("FAIL 载入失败: ", a[0])
		quit(1)
		return
	img.resize(int(a[2]), int(a[3]), Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(String(a[1])))
	print("OK %s → %s %sx%s" % [a[0], a[1], a[2], a[3]])
	quit()
