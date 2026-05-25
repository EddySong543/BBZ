extends SceneTree

## 立绘 → 正方形头像缩略图 自动生成器（演示/批处理）。
## 流程：① 背景近纯色则色键抠图（采样四角主色 → 相近像素转透明）
##       ② 检测人物非透明边界框
##       ③ 从人物顶部裁一个正方形（头+肩）
##       ④ 缩放到 THUMB 尺寸，存为 hXX_portrait.png
## 运行：godot --headless --path <proj> --script res://tools/gen_thumbnails.gd
## 当前为【演示模式】：只处理 h01，输出到 h01_portrait_auto.png（不覆盖现有文件）。

const THUMB := 160
const TOL := 0.14            # 色键容差（近纯色背景用）
const ALPHA_CUT := 0.30      # 判定"非透明"的阈值


func _initialize() -> void:
	_process_hero("h01", true)
	quit()


## demo=true 时输出到 *_portrait_auto.png（演示，不覆盖）；false 输出 *_portrait.png。
func _process_hero(id: String, demo: bool) -> void:
	var src := ProjectSettings.globalize_path("res://assets/sprites/heroes/%s/%s.png" % [id, id])
	var img := Image.load_from_file(src)
	if img == null:
		push_error("无法加载 " + src)
		return

	var w := img.get_width()
	var h := img.get_height()

	# ① 色键：若四角为不透明（纯色背景），抠掉与角色相近的背景色
	var corner := img.get_pixel(0, 0)
	if corner.a > 0.5:
		for y in range(h):
			for x in range(w):
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and _rgb_close(c, corner, TOL):
					img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))

	# ② 非透明边界框
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a >= ALPHA_CUT:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		push_error("%s：未检测到人物（全透明？）" % id)
		return

	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	# ③ 从人物顶部裁正方形（头+肩）：边长 = min(人物宽, 人物高)，水平居中、贴顶
	var side := mini(bw, bh)
	var cx := (minx + maxx) / 2
	var sx := clampi(cx - side / 2, 0, w - side)
	var sy := clampi(miny, 0, h - side)
	var thumb := img.get_region(Rect2i(sx, sy, side, side))

	# ④ 缩放到统一尺寸（保持像素清晰用 INTERPOLATE_NEAREST）
	thumb.resize(THUMB, THUMB, Image.INTERPOLATE_NEAREST)

	var suffix := "_portrait_auto" if demo else "_portrait"
	var out := ProjectSettings.globalize_path("res://assets/sprites/heroes/%s/%s%s.png" % [id, id, suffix])
	thumb.save_png(out)
	print("[thumb] %s：立绘 %dx%d，人物 bbox(%d,%d %dx%d)，裁 %dpx 方形 → %s" % [id, w, h, minx, miny, bw, bh, side, out])


func _rgb_close(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol
