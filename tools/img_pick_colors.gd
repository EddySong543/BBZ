extends SceneTree

## 像素取色（美术管线小工具·§15 范式"hex 从资产实测取"配套）：
##   godot --headless --path . -s tools/img_pick_colors.gd -- <图路径> <x1,y1> [<x2,y2> ...]
## 输出每个采样点的 hex（含 3×3 均值·防单像素噪点采偏）。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("用法: -- <图路径> <x,y> [<x,y> ...]")
		quit(1)
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(String(args[0])))
	if img == null:
		print("读图失败: ", args[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	for i in range(1, args.size()):
		var parts := String(args[i]).split(",")
		if parts.size() != 2:
			continue
		var x := int(parts[0])
		var y := int(parts[1])
		var c := img.get_pixel(x, y)
		var acc := Color(0, 0, 0, 0)
		var n := 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var px := x + dx
				var py := y + dy
				if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
					continue
				acc += img.get_pixel(px, py)
				n += 1
		var avg := acc / float(n)
		print("(%d,%d) 点=%s 3×3均=%s" % [x, y, c.to_html(false), avg.to_html(false)])
	quit(0)
