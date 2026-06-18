extends SceneTree

## 标题 logo 静态预览（开发调试用）：
##   godot --path . -s tools/title_preview.gd
## 跑完整入场动画后截图保存 → 自检王冠对齐 / 渐变 / 描边投影。
## 输出：D:/Game/BoBoZan/title_preview.png（仓库外）

const OUT_PATH := "D:/Game/BoBoZan/title_preview.png"


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#10141c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = root.get_visible_rect().size
	root.add_child(bg)
	var title := TitleLogo.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.size = root.get_visible_rect().size
	root.add_child(title)
	await process_frame   # 等 _ready/_build 完成（_initialize 阶段节点尚未就绪）
	title.play_entrance()
	# 入场 1.25s 完成 → 1.6s 时已进待机，截一帧
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(OUT_PATH)
	print("saved: ", OUT_PATH)
	_measure_title_center(img, title)
	# 再等约 1.5s 进入稳定待机补一帧（漂浮/微粒/水波线流动）
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_PATH.replace(".png", "_sheen.png"))
	print("saved idle frame")
	quit()


## 像素级测量标题整行水平中心 vs 屏幕中心（delta≈0 即居中），供居中调参。
func _measure_title_center(img: Image, title: TitleLogo) -> void:
	var row := title.get_title_rect()
	var row_c := _bright_center_x(img, row)
	var screen_c := img.get_width() * 0.5
	print("title_rect=", row)
	print("title_center=%.1f screen_center=%.1f delta=%.1f" % [row_c, screen_c, row_c - screen_c])


## 区域内亮像素（明度>0.3，排除背景/投影）的 x 范围中心。
func _bright_center_x(img: Image, r: Rect2) -> float:
	var min_x := 1e9
	var max_x := -1e9
	for y in range(maxi(int(r.position.y), 0), mini(int(r.end.y), img.get_height())):
		for x in range(maxi(int(r.position.x), 0), mini(int(r.end.x), img.get_width())):
			var p := img.get_pixel(x, y)
			if p.v > 0.3:
				min_x = minf(min_x, float(x))
				max_x = maxf(max_x, float(x))
	return (min_x + max_x) * 0.5
