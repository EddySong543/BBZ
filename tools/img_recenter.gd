extends SceneTree
## 图标重居中（美术管线小工具）：裁到非透明内容包围盒 → 居中垫回指定正方形画布 → 原路径覆盖。
##   godot --headless --path . -s tools/img_recenter.gd -- <res路径> <画布边长px>
## ⚠ 覆盖后必须跑一次 `--import` 重新导入（同路径覆盖贴图铁律）。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("用法: -- <res路径> <画布边长px>")
		quit(1)
		return
	var path := String(args[0])
	var canvas := int(args[1])
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		print("FAIL 载入失败: ", path)
		quit(1)
		return
	var r := img.get_used_rect()
	if r.size.x > canvas or r.size.y > canvas:
		print("FAIL 内容 %s 大于目标画布 %d" % [r.size, canvas])
		quit(1)
		return
	var content := img.get_region(r)
	var out := Image.create(canvas, canvas, false, Image.FORMAT_RGBA8)
	var dst := Vector2i((canvas - r.size.x) / 2, (canvas - r.size.y) / 2)
	out.blit_rect(content, Rect2i(Vector2i.ZERO, r.size), dst)
	out.save_png(ProjectSettings.globalize_path(path))
	print("OK %s: 内容 %s → 画布 %dx%d 居中@%s" % [path, r.size, canvas, canvas, dst])
	quit()
