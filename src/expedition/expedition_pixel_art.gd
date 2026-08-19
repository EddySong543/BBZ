## 远征模式 — 程序化像素图签库（任务 E：美术先行填充·零外部资源）。
##
## 手法 = 项目「像素粗格法」（ui-design-system §5）：8×8 点阵、整格纯色、无平滑无抖动。
## 点阵字符：`.`=透明  `x`=暗档  `X`=主色  `o`=亮档（暗/亮 = 主色 darkened/lightened 固定比）。
## 正式美术素材（MJ/pixellab）到位后按图签 id 逐个替换为贴图，调用面不动。
##
## 用法：
##   const PixelArt := preload("res://src/expedition/expedition_pixel_art.gd")
##   PixelArt.draw_icon(canvas, "gem", rect, Color("b08a3a"))       # 画进 CanvasItem
##   btn.icon = PixelArt.get_texture("potion", Color("4f9d52"))     # 生成缓存纹理（按钮用）
extends RefCounted

const DARKEN: float = 0.45
const LIGHTEN: float = 0.45

## 图签点阵库（8×8）。
const ICONS: Dictionary = {
	# —— 物品 ——
	"gem": [
		"...X....",
		"..XoX...",
		".XooXX..",
		"XooXXXx.",
		".XoXXx..",
		"..XXx...",
		"...x....",
		"........"],
	"ingot": [
		"........",
		"........",
		"..xxxx..",
		".xXXXXx.",
		".XooXXX.",
		"xXXXXXXx",
		"xxxxxxxx",
		"........"],
	"urn": [
		"..xXXx..",
		"...XX...",
		"..XooX..",
		".XoXXXx.",
		".XXXXXx.",
		".xXXXXx.",
		"..xXXx..",
		"...xx..."],
	"crown": [
		"........",
		"X..X..X.",
		"Xo.Xo.X.",
		"XXoXoXX.",
		".XXXXX..",
		".XoXoX..",
		".XXXXX..",
		"........"],
	"screen": [
		"x.x..x.x",
		"xXxXXxXx",
		"xXxXXxXx",
		"xoxXXxox",
		"xXxXXxXx",
		"xXxXXxXx",
		"xXxXXxXx",
		"x.x..x.x"],
	"potion": [
		"...xx...",
		"...XX...",
		"..xXXx..",
		".xXooXx.",
		".xXXXXx.",
		".xXXXXx.",
		"..xXXx..",
		"........"],
	"soup": [
		"........",
		"..o..o..",
		".x.oo.x.",
		"xXXXXXXx",
		"xXXXXXXx",
		".xXXXXx.",
		"..xxxx..",
		"........"],
	"shard": [
		"....x...",
		"...Xox..",
		"..XoXx..",
		".XoXXx..",
		".XXXx...",
		"xXXx....",
		"xXx.....",
		"x......."],
	"scroll": [
		"........",
		".xxxxxx.",
		"xXXXXXXx",
		".x.XX.x.",
		".x.XX.x.",
		".x.XX.x.",
		"xXXXXXXx",
		".xxxxxx."],
	"egg": [
		"...xx...",
		"..xXXx..",
		".xXoXXx.",
		".XoXXXx.",
		".XXXXXx.",
		".XXXXXx.",
		"..xXXx..",
		"...xx..."],
	"sword": [
		".......o",
		"......oX",
		".....oX.",
		"....oX..",
		".x.oX...",
		".xXX....",
		".xx.....",
		"x.x....."],
	# —— 地图 ——
	"chest": [
		"........",
		".xxxxxx.",
		"xXXXXXXx",
		"xXXooXXx",
		"xxxxxxxx",
		"xXXxxXXx",
		"xXXXXXXx",
		".xxxxxx."],
	"paw": [
		"........",
		".X..X...",
		"......X.",
		"..xxx...",
		".xXXXx..",
		".XXXXX..",
		"..XXX...",
		"........"],
	"fang": [
		"........",
		"X......X",
		"Xx....xX",
		"XXx..xXX",
		".XX..XX.",
		".Xo..oX.",
		"..X..X..",
		"........"],
	"horns": [
		"x......x",
		"xx....xx",
		".xXXXXx.",
		".XoXXoX.",
		".XXXXXX.",
		"..XxxX..",
		"..XXXX..",
		"........"],
	"flag": [
		"..X.....",
		"..XooX..",
		"..XoooX.",
		"..XooX..",
		"..X.....",
		"..X.....",
		"..X.....",
		"..X....."],
	"arch": [
		"..XXXX..",
		".Xx..xX.",
		".X....X.",
		".X.oo.X.",
		".X.oo.X.",
		".X....X.",
		".X....X.",
		"........"],
	"tent": [
		"........",
		"...XX...",
		"..XXXX..",
		".XXxxXX.",
		".XxXXxX.",
		"XXxXXxXX",
		"xxxxxxxx",
		"........"],
	"eye": [
		"........",
		"..xXXx..",
		".XXooXX.",
		"XXoXXoXX",
		".XXooXX.",
		"..xXXx..",
		"........",
		"........"],
}

static var _tex_cache: Dictionary = {}


## 把图签画进 CanvasItem（rect 内均分 8×8 块）。
static func draw_icon(ci: CanvasItem, icon_id: String, rect: Rect2, base: Color) -> void:
	if not ICONS.has(icon_id):
		return
	var rows: Array = ICONS[icon_id]
	var bs: Vector2 = rect.size / 8.0
	var dark: Color = base.darkened(DARKEN)
	var light: Color = base.lightened(LIGHTEN)
	for y: int in 8:
		var row: String = rows[y]
		for x: int in 8:
			var ch: String = row[x]
			if ch == ".":
				continue
			var col: Color = base
			if ch == "x":
				col = dark
			elif ch == "o":
				col = light
			ci.draw_rect(Rect2(rect.position + Vector2(x, y) * bs, bs.ceil()), col)


## 图签生成纹理（缓存·按钮 icon 用）。px = 输出边长。
static func get_texture(icon_id: String, base: Color, px: int = 32) -> Texture2D:
	var key: String = "%s|%s|%d" % [icon_id, base.to_html(), px]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	if ICONS.has(icon_id):
		var rows: Array = ICONS[icon_id]
		var bs: int = maxi(1, px / 8)
		var dark: Color = base.darkened(DARKEN)
		var light: Color = base.lightened(LIGHTEN)
		for y: int in 8:
			var row: String = rows[y]
			for x: int in 8:
				var ch: String = row[x]
				if ch == ".":
					continue
				var col: Color = base
				if ch == "x":
					col = dark
				elif ch == "o":
					col = light
				img.fill_rect(Rect2i(x * bs, y * bs, bs, bs), col)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


## 地板/墙/迷雾绘制已移交 canvas_ui_expedition_terrain.gdshader（2026-07-07 精细化批）——
## 本库只留图签（draw_icon / get_texture）。旧 draw_floor/draw_wall/cell_hash 随之移除。
