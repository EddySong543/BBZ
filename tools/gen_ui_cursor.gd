extends SceneTree

## 鼠标指针生成器（G 件·B 方案「族语化经典箭头」·2026-07-15 Eddy 选 B·程序自产零外部资产）：
## 经典箭头剪影（认知零成本）+ 家族材质。**v2 暖色版（Eddy 2026-07-15：避免暗色主色）**：
## 暖纸身 #F0D7A2 + 近黑描边 #130C08——亮填充+暗轮廓=§2 取色铁律（暗夜亮身跳出·亮纸暗轮廓勾形）。
## 悬停变体=身换暖金 #D4A94E（描边不动）。24×24 设计网格 ×2 = 48×48 成品（描边 1 设计格=2 成品px）。
## 跑法：godot --headless --path . -s res://tools/gen_ui_cursor.gd
## 输出：assets/ui/cursor_arrow.png / cursor_hand.png + stdout 打 hotspot 像素坐标。
## ⚠ 覆盖同路径贴图后必须跑 --import（老规矩）。

const GRID := 24
const SCALE := 2
const BODY := Color("F0D7A2")        # 暖纸身（牌匾/导航钮族纸面色·资产实测）
const BODY_HOVER := Color("D4A94E")  # 悬停=身换暖金（牌匾族金）
const RIM := Color("130C08")         # 近黑描边（悬停框族近黑·亮纸上勾形）

# 箭头身（设计格行段表：y -> [x_start, x_end] 列表·手调迭代口）。
# 头=经典三角（尖 (3,2)·45° 斜边·左缘垂直）；尾=右倾短腿收回纹钩（下横+上挑=方折「回」意）。
const SPANS := {
	2:  [[3, 3]],
	3:  [[3, 4]],
	4:  [[3, 5]],
	5:  [[3, 6]],
	6:  [[3, 7]],
	7:  [[3, 8]],
	8:  [[3, 9]],
	9:  [[3, 10]],
	10: [[3, 11]],
	11: [[3, 12]],
	12: [[3, 13]],
	13: [[3, 6], [8, 10]],
	14: [[3, 5], [8, 10]],
	15: [[3, 4], [9, 11]],
	16: [[3, 3], [9, 11]],
	17: [[10, 12]],
	18: [[10, 12]],
	19: [[10, 15]],
	20: [[10, 15]],
}
# （尾部=单记直角右甩；首版"上挑笔+底横"回纹钩在 48px 糊成实心块的教训见 git 史）


func _init() -> void:
	var body_px := {}
	for y: int in SPANS:
		for span: Array in SPANS[y]:
			for x in range(int(span[0]), int(span[1]) + 1):
				body_px[Vector2i(x, y)] = true

	for variant: Array in [["cursor_arrow", BODY], ["cursor_hand", BODY_HOVER]]:
		var body_col: Color = variant[1]
		var img := Image.create(GRID * SCALE, GRID * SCALE, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		# 第一遍：描边=身像素的 8 邻域中非身格（家族两遍描边法·近黑勾形）
		for p: Vector2i in body_px:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n := p + Vector2i(dx, dy)
					if not body_px.has(n):
						_put(img, n, RIM)
		# 第二遍：身色盖上（普通=暖纸·悬停=暖金）
		for p: Vector2i in body_px:
			_put(img, p, body_col)
		var path := "res://assets/ui/%s.png" % variant[0]
		img.save_png(ProjectSettings.globalize_path(path))
		print("saved: %s" % path)

	# hotspot=全图最靠左上的不透明像素（x+y 最小·并列取 y 小）——即描边尖端
	var probe := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/cursor_arrow.png"))
	var best := Vector2i(9999, 9999)
	for y in probe.get_height():
		for x in probe.get_width():
			if probe.get_pixel(x, y).a > 0.5:
				if x + y < best.x + best.y or (x + y == best.x + best.y and y < best.y):
					best = Vector2i(x, y)
	print("hotspot: %s" % best)
	quit()


func _put(img: Image, p: Vector2i, col: Color) -> void:
	for dy in SCALE:
		for dx in SCALE:
			var px := p.x * SCALE + dx
			var py := p.y * SCALE + dy
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
