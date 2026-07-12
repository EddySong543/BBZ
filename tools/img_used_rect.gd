extends SceneTree
## 图片非透明内容边界测量（美术管线小工具）：
##   godot --headless --path . -s tools/img_used_rect.gd -- <res路径1> [<res路径2> ...]
## 输出：每张图的画布尺寸 + get_used_rect()（非透明像素包围盒）+ 四边留白 px。

func _init() -> void:
	for p in OS.get_cmdline_user_args():
		var img := Image.load_from_file(ProjectSettings.globalize_path(p))
		if img == null:
			print("FAIL 载入失败: ", p)
			continue
		var r := img.get_used_rect()
		# 中列不透明行范围（横幅/卷轴类：中段内容的纵向实际跨度）
		var cx := img.get_width() / 2
		var top := -1
		var bottom := -1
		for y in img.get_height():
			if img.get_pixel(cx, y).a > 0.02:
				if top < 0:
					top = y
				bottom = y
		print("%s | 画布 %dx%d | 内容 %s | 留白 左%d 右%d 上%d 下%d | 中列不透明 y%d-%d" % [
			p, img.get_width(), img.get_height(), r,
			r.position.x, img.get_width() - r.end.x,
			r.position.y, img.get_height() - r.end.y, top, bottom])
	quit()
