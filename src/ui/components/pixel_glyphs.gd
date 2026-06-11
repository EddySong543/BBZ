class_name PixelGlyphs
extends RefCounted

## 标题专用手工像素字形库 ——「波 / 攒 / 之 / 王」+ 王冠。
##
## Ark Pixel 16px 放大后观感不佳（Eddy 反馈），故为标题手工造字：
## 32×32 网格、粗笔画书法风 + 夸张处理（王=厚重底横带燕尾、之/波=长捺压笔）。
## 字形用"笔画 DSL"描述（矩形 + 带粗细的阶梯斜线），栅格化成白色填充 + 黑色描边
## 的 ImageTexture，运行时由 TextureRect.modulate 着色（黑描边乘任何色仍为黑）。
##
## 调试：tools/dump_glyphs.gd 可在终端 ASCII 预览所有字形。

const GRID := 32
const PAD := 2          # 四周留白给 1px 描边
const IMG_SIZE := GRID + PAD * 2

## 笔画 DSL：
##   ["r", x, y, w, h]          —— 实心矩形
##   ["l", x0, y0, x1, y1, t]   —— 阶梯直线（沿主轴步进，逐步盖 t×t 方块）
const GLYPHS: Dictionary = {
	"波": [
		# 氵（三点水：两点 + 上挑提）
		["r", 3, 2, 4, 4],
		["r", 1, 10, 4, 4],
		["l", 1, 23, 7, 16, 3],
		# 皮：横钩 / 竖 / 左撇 / 又（横撇 + 长捺压笔）
		["r", 10, 2, 19, 3],
		["r", 26, 5, 3, 4],
		["r", 18, 2, 3, 12],
		["l", 13, 6, 8, 15, 3],
		["r", 10, 14, 16, 3],
		["l", 23, 17, 11, 28, 3],
		["l", 15, 17, 27, 26, 3],
		["r", 26, 26, 5, 3],
	],
	"攒": [
		# 扌（竖钩 + 横 + 提）
		["r", 4, 1, 3, 25],
		["r", 1, 24, 3, 3],
		["r", 0, 6, 8, 2],
		["l", 0, 16, 7, 12, 2],
		# 先 ×2（顶撇 / 横 / 竖 / 宽横 / 儿）
		["r", 12, 0, 2, 3],
		["r", 9, 3, 10, 2],
		["r", 12, 0, 2, 8],
		["r", 9, 7, 10, 2],
		["l", 12, 9, 9, 14, 2],
		["r", 14, 9, 2, 4],
		["r", 14, 12, 4, 2],
		["r", 16, 10, 2, 2],
		["r", 23, 0, 2, 3],
		["r", 20, 3, 10, 2],
		["r", 23, 0, 2, 8],
		["r", 20, 7, 10, 2],
		["l", 23, 9, 20, 14, 2],
		["r", 25, 9, 2, 4],
		["r", 25, 12, 4, 2],
		["r", 27, 10, 2, 2],
		# 贝（开底框 + 撇点双腿）
		["r", 11, 16, 17, 2],
		["r", 11, 16, 2, 9],
		["r", 26, 16, 2, 9],
		["l", 15, 23, 10, 29, 2],
		["l", 21, 23, 26, 29, 2],
	],
	"之": [
		# 斜点（两块错位）
		["r", 14, 1, 5, 3],
		["r", 12, 3, 5, 3],
		# 横撇
		["r", 8, 9, 14, 3],
		["l", 19, 12, 10, 19, 3],
		# 长捺 + 压笔尾（夸张拖长）
		["l", 10, 19, 21, 25, 3],
		["r", 20, 25, 10, 4],
	],
	"王": [
		# 三横一竖；底横厚重 + 两端燕尾上挑（王者基座）
		["r", 5, 3, 22, 4],
		["r", 8, 14, 16, 4],
		["r", 14, 3, 4, 22],
		["r", 2, 25, 28, 5],
		["r", 2, 22, 4, 3],
		["r", 26, 22, 4, 3],
	],
}

## 王冠像素稿（26×15·2026-06-10 重绘增质感）：三峰带珍珠尖 + 峰身高光/内侧阴影 +
## 高光带 + 宝石饰带 + 双层基座（暗金 + 深影收底）。
## 宝石配色（Eddy 决议）：左蓝=波蓝 / 中白=钻石（双波相争的中立王座）/ 右红=波红。
## 'L'=亮金高光 '#'=金 '+'=暗金阴影 'x'=深影 'r'=宝石主体 'w'=宝石闪点（实际色按列归属取 GEM_COLORS）
const CROWN_ROWS: Array[String] = [
	"............LL............",
	"...........L##L...........",
	"...LL.......##.......LL...",
	"..L##L......##......L##L..",
	"..####.....L##L.....####..",
	"..###+.....####.....+###..",
	"..####L...L####L...L####..",
	"..#####L..######..L#####..",
	"..######LL######LL######..",
	".L######################L.",
	".LLLLLLLLLLLLLLLLLLLLLLLL.",
	".##wr#######wr#######wr##.",
	".##rr#######rr#######rr##.",
	".++++++++++++++++++++++++.",
	"..xxxxxxxxxxxxxxxxxxxxxx..",
]
const CROWN_COLORS: Dictionary = {
	"L": Color("#ffe08a"),
	"#": Color("#f4c84b"),
	"+": Color("#b8862f"),
	"x": Color("#7a5518"),
	"r": Color("#d7342e"),   # 占位——宝石实际色按列归属取 GEM_COLORS
	"w": Color("#ff9d94"),
}
## 三宝石主体/闪点色：左蓝（wave_clash 蓝波亮档）/ 中白钻 / 右红（红波亮档）
const GEM_COLORS: Array[Color] = [
	Color(0.30, 0.60, 1.00), Color("#e8eef7"), Color(0.95, 0.32, 0.22),
]
const GEM_GLINTS: Array[Color] = [
	Color("#b3e0ff"), Color("#ffffff"), Color("#ffa673"),
]
const GEM_SPARKLE := Color("#fff1ef")   # 宝石闪烁帧的高亮色

static var _cache: Dictionary = {}


## 字形纹理：白填充 + 黑描边，PAD 留白，无滤波（调用方需设 NEAREST）。
static func glyph_texture(ch: String) -> ImageTexture:
	if _cache.has(ch):
		return _cache[ch]
	var img := _rasterize(GLYPHS[ch])
	var tex := ImageTexture.create_from_image(img)
	_cache[ch] = tex
	return tex


## 王冠纹理：彩色像素稿 + 黑描边。
## sparkle_gem = 0/1/2 时对应宝石（左/中/右）整颗打亮——宝石轮闪动画帧；-1 = 常态。
static func crown_texture(sparkle_gem: int = -1) -> ImageTexture:
	var key := "crown%d" % sparkle_gem
	if _cache.has(key):
		return _cache[key]
	var w := CROWN_ROWS[0].length() + PAD * 2
	var h := CROWN_ROWS.size() + PAD * 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for ry in CROWN_ROWS.size():
		var row := CROWN_ROWS[ry]
		for rx in row.length():
			var c := row[rx]
			if not CROWN_COLORS.has(c):
				continue
			var col: Color = CROWN_COLORS[c]
			if c == "r" or c == "w":
				var gem := _gem_cluster(rx)
				col = GEM_SPARKLE if sparkle_gem == gem \
					else (GEM_GLINTS[gem] if c == "w" else GEM_COLORS[gem])
			img.set_pixel(rx + PAD, ry + PAD, col)
	_apply_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 宝石按 x 列归属：左(0) / 中(1) / 右(2)。
static func _gem_cluster(rx: int) -> int:
	if rx < 9:
		return 0
	return 1 if rx < 18 else 2


static func _rasterize(ops: Array) -> Image:
	var img := Image.create(IMG_SIZE, IMG_SIZE, false, Image.FORMAT_RGBA8)
	for op_v in ops:
		var op: Array = op_v
		match op[0]:
			"r":
				_fill_rect(img, op[1], op[2], op[3], op[4])
			"l":
				_stamp_line(img, op[1], op[2], op[3], op[4], op[5])
	_apply_outline(img)
	return img


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			_put(img, px, py)


## 阶梯直线：沿主轴逐像素步进，每步盖一个 t×t 方块（左上角锚点）。
static func _stamp_line(img: Image, x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var steps: int = maxi(absi(dx), absi(dy))
	for i in steps + 1:
		var u := float(i) / float(maxi(steps, 1))
		var px := roundi(lerpf(float(x0), float(x1), u))
		var py := roundi(lerpf(float(y0), float(y1), u))
		for oy in t:
			for ox in t:
				_put(img, px + ox, py + oy)


static func _put(img: Image, px: int, py: int) -> void:
	var x := px + PAD
	var y := py + PAD
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, Color.WHITE)


## 描边：所有与实色像素 8 邻接的透明像素 → 纯黑。
static func _apply_outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edge: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			var touches := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var p := img.get_pixel(nx, ny)
					if p.a > 0.0 and not p.is_equal_approx(Color.BLACK):
						touches = true
						break
				if touches:
					break
			if touches:
				edge.append(Vector2i(x, y))
	for v in edge:
		img.set_pixel(v.x, v.y, Color.BLACK)


## 终端 ASCII 预览（调试用）："█"=填充 "▒"=描边。
static func dump(ch: String) -> String:
	var img: Image
	if ch == "crown":
		var w := CROWN_ROWS[0].length() + PAD * 2
		var h := CROWN_ROWS.size() + PAD * 2
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for ry in CROWN_ROWS.size():
			var row := CROWN_ROWS[ry]
			for rx in row.length():
				if CROWN_COLORS.has(row[rx]):
					img.set_pixel(rx + PAD, ry + PAD, Color.WHITE)
		_apply_outline(img)
	else:
		img = _rasterize(GLYPHS[ch])
	var out := ""
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a <= 0.0:
				out += "·"
			elif p.is_equal_approx(Color.BLACK):
				out += "▒"
			else:
				out += "█"
		out += "\n"
	return out
