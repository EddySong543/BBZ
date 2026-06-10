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
	_measure_crown_alignment(img, title)
	# 再等到首道待机掠光中段（落定 1.25s + 预热 1.5s + 半程 0.3s ≈ 3.05s）补一帧
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_PATH.replace(".png", "_sheen.png"))
	print("saved sheen frame")
	quit()


## 像素级测量王冠与「王」字身的水平中心差（正=王冠偏右），供对齐调参。
func _measure_crown_alignment(img: Image, title: TitleLogo) -> void:
	var crown := title.get_crown_rect()
	var king := title.get_king_rect()
	var crown_c := _bright_center_x(img, crown)
	var king_c := _bright_center_x(img, king)
	print("crown_rect=", crown, " king_rect=", king)
	print("crown_center=%.1f king_center=%.1f delta=%.1f" % [crown_c, king_c, crown_c - king_c])


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
