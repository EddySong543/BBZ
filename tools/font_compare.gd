extends SceneTree

## 标题三字体对比图生成器（开发调试用）：
##   godot --path . -s tools/font_compare.gd
## 渲染「波波攒之王」三个字体版本（含标题配色 + 黑描边）→ 截图保存后自动退出。
## 输出：D:/Game/BoBoZan/font_compare.png（仓库外，避免被 Godot 导入系统收编）

const OUT_PATH := "D:/Game/BoBoZan/font_compare.png"
const TITLE := "波波攒之王"
const ROWS: Array = [
	# [说明, 字体路径, 显示尺寸(整数倍), 描边(=1字体像素)]
	["Fusion Pixel 10px  x12 = 120px",
		"res://assets/font/fusion-pixel-10px-proportional-zh_hans.ttf", 120, 12],
	["Ark Pixel 12px  x10 = 120px",
		"res://assets/font/ark-pixel-12px-proportional-zh_cn.ttf", 120, 10],
	["Ark Pixel 16px  x8 = 128px",
		"res://assets/font/ark-pixel-16px-proportional-zh_cn.ttf", 128, 8],
]
const CHAR_COLORS: Array = [
	Color(0.30, 0.60, 1.00),   # 波₁ 蓝
	Color(0.95, 0.32, 0.22),   # 波₂ 红
	Color("#e8eef7"),          # 攒 白
	Color("#e8eef7"),          # 之 白
	Color("#f4c84b"),          # 王 金
]


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#10141c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var caption_font := load("res://assets/font/ark-pixel-12px-proportional-zh_cn.ttf") as FontFile
	caption_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE

	var y := 40.0
	for row_v in ROWS:
		var row: Array = row_v
		var cap := Label.new()
		cap.text = row[0]
		cap.add_theme_font_override("font", caption_font)
		cap.add_theme_font_size_override("font_size", 24)
		cap.add_theme_color_override("font_color", Color("#9aa7bd"))
		cap.position = Vector2(60, y)
		bg.add_child(cap)
		y += 44.0

		var font := load(row[1]) as FontFile
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		var x := 60.0
		for i in TITLE.length():
			var lb := Label.new()
			lb.text = TITLE[i]
			lb.add_theme_font_override("font", font)
			lb.add_theme_font_size_override("font_size", row[2])
			lb.add_theme_color_override("font_color", CHAR_COLORS[i])
			lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			lb.add_theme_constant_override("outline_size", row[3])
			lb.position = Vector2(x, y)
			bg.add_child(lb)
			# 首帧前 Label.get_minimum_size() 未反映字体覆写 → 直接用字体量宽
			x += font.get_string_size(TITLE[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, row[2]).x + 12.0
		y += row[2] + 56.0

	# 等两帧确保绘制完成 → 截图 → 退出
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(OUT_PATH)
	print("saved: ", OUT_PATH)
	quit()
