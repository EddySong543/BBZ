extends SceneTree

## defeat 表朝向核验（headless）：对每张 import 区死亡表，取首帧与该英雄 idle 首帧比对——
## 「原样」与「水平翻转」两种假设各算一次差异分，翻转分显著更低 = 表是镜像的（GPT 出反了）。
## 差异分 = 两帧 alpha 掩模的不重合像素数（对齐各自 bbox 中心后）。另存 h17 并排放大图供目检。
##   godot --headless --path . --script res://tools/defeat_orient_probe.gd
## 输出：逐英雄判定行 + D:/Game/BoBoZan/h17_orient_check.png

const IMPORT_DIR := "res://assets/import/"
const DST := "res://assets/sprites/heroes/"
const CELL := 256


func _initialize() -> void:
	var da := DirAccess.open(IMPORT_DIR)
	da.list_dir_begin()
	var f := da.get_next()
	var ids: Array[String] = []
	while f != "":
		if f.match("h??_defeat.png"):
			ids.append(f.substr(0, 3))
		f = da.get_next()
	da.list_dir_end()
	ids.sort()
	for id in ids:
		_check(id)
	quit()


func _first_cell(img: Image) -> Image:
	# 首个非空格（逐行扫）
	var cols := img.get_width() / CELL
	var rows := img.get_height() / CELL
	for r in rows:
		for c in cols:
			var cellimg := img.get_region(Rect2i(c * CELL, r * CELL, CELL, CELL))
			if not cellimg.get_used_rect().has_area():
				continue
			return cellimg
	return null


## alpha 掩模差异（对齐 bbox 中心）：返回不重合像素数。
func _mask_diff(a: Image, b: Image) -> int:
	var ra := a.get_used_rect()
	var rb := b.get_used_rect()
	var diff := 0
	var w: int = maxi(ra.size.x, rb.size.x)
	var h: int = maxi(ra.size.y, rb.size.y)
	for y in h:
		for x in w:
			var pa := false
			var pb := false
			var ax: int = ra.position.x + x - (w - ra.size.x) / 2
			var ay: int = ra.position.y + y - (h - ra.size.y) / 2
			var bx: int = rb.position.x + x - (w - rb.size.x) / 2
			var by: int = rb.position.y + y - (h - rb.size.y) / 2
			if ax >= 0 and ay >= 0 and ax < a.get_width() and ay < a.get_height():
				pa = a.get_pixel(ax, ay).a > 0.1
			if bx >= 0 and by >= 0 and bx < b.get_width() and by < b.get_height():
				pb = b.get_pixel(bx, by).a > 0.1
			if pa != pb:
				diff += 1
	return diff


func _check(id: String) -> void:
	var dimg := Image.load_from_file(ProjectSettings.globalize_path(IMPORT_DIR + id + "_defeat.png"))
	var ipath := ProjectSettings.globalize_path("%s%s/%s_idle.png" % [DST, id, id])
	var iimg := Image.load_from_file(ipath)
	if dimg == null or iimg == null:
		print("[%s] 素材缺失·跳过" % id)
		return
	var d0 := _first_cell(dimg)
	var i0 := _first_cell(iimg)
	if d0 == null or i0 == null:
		print("[%s] 首帧提取失败" % id)
		return
	var straight := _mask_diff(d0, i0)
	var flipped_img := Image.new()
	flipped_img.copy_from(d0)
	flipped_img.flip_x()
	var flipped := _mask_diff(flipped_img, i0)
	var verdict := "原样"
	if flipped < straight * 0.85:
		verdict = "⚠镜像（翻转差 %d < 原样差 %d）" % [flipped, straight]
	print("[%s] 原样差=%d 翻转差=%d → %s" % [id, straight, flipped, verdict])
	if id == "h17":
		_save_compare(i0, d0, flipped_img)


## h17 目检图：idle首帧 | defeat首帧 | defeat首帧翻转 三联 2× 放大。
func _save_compare(i0: Image, d0: Image, dflip: Image) -> void:
	var out := Image.create(CELL * 3, CELL, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.12, 0.12, 0.14, 1.0))
	out.blit_rect_mask(i0, i0, Rect2i(0, 0, CELL, CELL), Vector2i(0, 0))
	out.blit_rect_mask(d0, d0, Rect2i(0, 0, CELL, CELL), Vector2i(CELL, 0))
	out.blit_rect_mask(dflip, dflip, Rect2i(0, 0, CELL, CELL), Vector2i(CELL * 2, 0))
	out.resize(CELL * 6, CELL * 2, Image.INTERPOLATE_NEAREST)
	out.save_png("D:/Game/BoBoZan/h17_orient_check.png")
	print("saved: D:/Game/BoBoZan/h17_orient_check.png")
	# 末排四帧 2× 放大（倒地姿态细节目检）
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(IMPORT_DIR + "h17_defeat.png"))
	if sheet != null:
		var strip := sheet.get_region(Rect2i(0, CELL * 2, CELL * 4, CELL))
		strip2x(strip)


func strip2x(strip: Image) -> void:
	var bg := Image.create(strip.get_width(), strip.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.12, 0.12, 0.14, 1.0))
	bg.blit_rect_mask(strip, strip, Rect2i(0, 0, strip.get_width(), strip.get_height()), Vector2i.ZERO)
	bg.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
	bg.save_png("D:/Game/BoBoZan/h17_lastrow.png")
	print("saved: D:/Game/BoBoZan/h17_lastrow.png")
