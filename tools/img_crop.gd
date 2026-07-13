extends SceneTree
## 图片裁切+放大（美术管线小工具）：截图自检时裁局部放大目检用。
##   godot --headless --path . -s tools/img_crop.gd -- <源路径> <目标路径> <x> <y> <w> <h> [放大倍=1]
## 路径可为 res:// 或绝对盘符路径（内部 globalize）。放大用 NEAREST（保像素·目检不糊）。

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 6:
		print("用法: -- <源> <目标> <x> <y> <w> <h> [放大倍=1]")
		quit(1)
		return
	var src := String(a[0])
	var dst := String(a[1])
	var r := Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))
	var scale := int(a[6]) if a.size() > 6 else 1
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		print("FAIL 载入失败: ", src)
		quit(1)
		return
	var out := img.get_region(r)
	if scale > 1:
		out.resize(r.size.x * scale, r.size.y * scale, Image.INTERPOLATE_NEAREST)
	out.save_png(ProjectSettings.globalize_path(dst))
	print("OK %s [%s] ×%d → %s" % [src, r, scale, dst])
	quit()
