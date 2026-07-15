extends SceneTree

## 鼠标指针美术落位（一次性·2026-07-15·Eddy GPT 出图「鼠标箭头.png」）：
## ① 棋盘假透明→真透明（亮中性全局判·身=暖纸高饱和/描边=近黑·都不误伤）
## ② 量 texel 粒径（左缘描边厚度=1 texel·三高度取中位）→ 量化到设计格（NEAREST 格心采样+alpha 二值化）
## ③ ×2 放大=2px/texel 成品 → assets/ui/cursor_arrow.png
## ④ 悬停版=全图乘色 (212/240,169/215,78/162)：暖纸身 F0D7A2→暖金 D4A94E·近黑描边几乎不动
## ⑤ stdout 打成品尺寸+尖端 hotspot（回填 transition_manager.CURSOR_HOTSPOT）
## 跑法：godot --headless --path . -s res://tools/import_cursor_art.gd（跑完 --import）

const SRC := "res://assets/import/鼠标箭头.png"
const DST_ARROW := "res://assets/ui/cursor_arrow.png"
const DST_HAND := "res://assets/ui/cursor_hand.png"
const HOVER_MUL := Color(212.0 / 240.0, 169.0 / 215.0, 78.0 / 162.0)
const MARGIN := 1   # 成品四周留白 texel（描边贴边会被 OS 光标边界裁）


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		print("FAIL 源图加载失败")
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	print("源图 %dx%d" % [img.get_width(), img.get_height()])

	# ① 棋盘→真透明（明度≥0.70 且饱和≤0.10 → 透明）
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var hi := maxf(c.r, maxf(c.g, c.b))
			var lo := minf(c.r, minf(c.g, c.b))
			if hi >= 0.70 and hi - lo <= 0.10:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				n += 1
	var bbox := img.get_used_rect()
	print("转透明 %d px · 内容 bbox %s" % [n, bbox])

	# ② texel 粒径=左缘描边横向厚度（三个高度取中位·描边=1 texel）
	var runs: Array[int] = []
	for frac: float in [0.3, 0.5, 0.7]:
		var yy := bbox.position.y + int(bbox.size.y * frac)
		var run := 0
		var started := false
		for x in range(bbox.position.x, bbox.end.x):
			var c := img.get_pixel(x, yy)
			if c.a > 0.5 and maxf(c.r, maxf(c.g, c.b)) < 0.45:
				run += 1
				started = true
			elif started:
				break
		if run > 0:
			runs.append(run)
	runs.sort()
	if runs.is_empty():
		print("FAIL 左缘描边测不到")
		quit(1)
		return
	var k: int = runs[runs.size() / 2]
	var n_w := int(round(bbox.size.x / float(k)))
	var n_h := int(round(bbox.size.y / float(k)))
	print("texel=%dpx（样本%s）→ 设计格 %dx%d" % [k, str(runs), n_w, n_h])

	# ③ 量化到设计格（NEAREST=格心采样）+ alpha 二值化 → ×2 成品
	var grid := img.get_region(bbox)
	grid.resize(n_w, n_h, Image.INTERPOLATE_NEAREST)
	for y in grid.get_height():
		for x in grid.get_width():
			var c := grid.get_pixel(x, y)
			if c.a < 0.5:
				grid.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				grid.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	var out_w := (n_w + MARGIN * 2) * 2
	var out_h := (n_h + MARGIN * 2) * 2
	var arrow := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	arrow.fill(Color(0, 0, 0, 0))
	var up := grid.duplicate() as Image
	up.resize(n_w * 2, n_h * 2, Image.INTERPOLATE_NEAREST)
	arrow.blit_rect(up, Rect2i(0, 0, up.get_width(), up.get_height()), Vector2i(MARGIN * 2, MARGIN * 2))
	var err := arrow.save_png(ProjectSettings.globalize_path(DST_ARROW))
	print("cursor_arrow: %dx%d (err=%d)" % [out_w, out_h, err])

	# ④ 悬停版=全图乘色（身→暖金·描边近黑几乎不动）
	var hand := arrow.duplicate() as Image
	for y in hand.get_height():
		for x in hand.get_width():
			var c := hand.get_pixel(x, y)
			if c.a > 0.0:
				hand.set_pixel(x, y, Color(c.r * HOVER_MUL.r, c.g * HOVER_MUL.g, c.b * HOVER_MUL.b, c.a))
	err = hand.save_png(ProjectSettings.globalize_path(DST_HAND))
	print("cursor_hand: 乘色派生 (err=%d)" % err)

	# ⑤ hotspot=最靠左上的不透明像素（x+y 最小·并列取 y 小）
	var best := Vector2i(9999, 9999)
	for y in arrow.get_height():
		for x in arrow.get_width():
			if arrow.get_pixel(x, y).a > 0.5:
				if x + y < best.x + best.y or (x + y == best.x + best.y and y < best.y):
					best = Vector2i(x, y)
	print("hotspot: %s（回填 transition_manager.CURSOR_HOTSPOT）" % best)
	quit()
