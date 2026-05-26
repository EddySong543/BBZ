extends SceneTree

## 英雄美术导入（A 方案）：为 h01-h17 生成 idle.tres + 方形头像，并回填 v4 .tres 路径。
## 前置：hXX.png(立绘) + hXX_idle.png(sheet) 已复制到 heroes/hXX/ 且已 --import。
## 运行：godot --headless --path <proj> --script res://tools/import_hero_art.gd
##
## idle.tres：4 列 × 256px 网格，逐格遍历，跳过全透明帧，speed 8 / loop。
## 头像：立绘已是透明背景 → alpha bbox → 从人物顶部裁正方形(头+肩) → 缩放 THUMB。

const DST := "res://assets/sprites/heroes/"
const HERO_DATA := "res://assets/data/heroes/"
const FIRST := 1
const LAST := 17

const CELL := 256
const COLS := 4
const ANIM_FPS := 8.0

const THUMB := 160
const ALPHA_CUT := 0.30
const HEAD_RATIO := 0.5      # 头像方形边长 = 人物高度 × 此比例（取头+肩，所有英雄一致）
const REGEN_PORTRAIT := false  # false=已存在头像跳过（保护 Eddy 手动放的 hXX_portrait.png）；改 true 强制重生成


func _initialize() -> void:
	var ok := 0
	for i in range(FIRST, LAST + 1):
		var id := "h%02d" % i
		var a := _gen_idle_tres(id)
		var b := _gen_portrait(id)
		var c := _update_v4_tres(id)
		if a and b and c:
			ok += 1
	print("=== 导入完成：%d/%d 英雄全部成功 ===" % [ok, LAST - FIRST + 1])
	quit()


## 生成 hXX_idle.tres（跳过全透明帧）。
func _gen_idle_tres(id: String) -> bool:
	var png := "%s%s/%s_idle.png" % [DST, id, id]
	if not ResourceLoader.exists(png):
		push_error("%s: idle.png 未 import（缺 %s）" % [id, png])
		return false
	var tex: Texture2D = load(png)
	var img := Image.load_from_file(ProjectSettings.globalize_path(png))
	if tex == null or img == null:
		push_error("%s: idle 加载失败" % id)
		return false

	var rows: int = img.get_height() / CELL
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", ANIM_FPS)
	sf.set_animation_loop("idle", true)
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var frames := 0
	for r in range(rows):
		for c in range(COLS):
			if _cell_empty(img, c * CELL, r * CELL):
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * CELL, r * CELL, CELL, CELL)
			sf.add_frame("idle", atlas)
			frames += 1

	if frames == 0:
		push_error("%s: idle 无有效帧" % id)
		return false
	var out := "%s%s/%s_idle.tres" % [DST, id, id]
	var err := ResourceSaver.save(sf, out)
	print("[idle] %s: %d 行 → %d 帧 → %s (err=%d)" % [id, rows, frames, out, err])
	return err == OK


## 立绘 → 方形头像。立绘已透明背景，直接 alpha bbox。
func _gen_portrait(id: String) -> bool:
	var out_path := "%s%s/%s_portrait.png" % [DST, id, id]
	if not REGEN_PORTRAIT and FileAccess.file_exists(ProjectSettings.globalize_path(out_path)):
		print("[thumb] %s: 头像已存在，跳过（保护手动头像；改 REGEN_PORTRAIT=true 强制重生成）" % id)
		return true
	var src := ProjectSettings.globalize_path("%s%s/%s.png" % [DST, id, id])
	var img := Image.load_from_file(src)
	if img == null:
		push_error("%s: 立绘加载失败 %s" % [id, src])
		return false
	var w := img.get_width()
	var h := img.get_height()

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
		push_error("%s: 立绘全透明，无法裁头像" % id)
		return false

	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	# 一致头像：边长 = 人物高度 × HEAD_RATIO（取头+肩）。不用 min(bw,bh)——否则宽姿势
	# 人物(如持横剑)会 side=高度裁成全身，瘦高人物 side=宽度裁成头，两者不一致。
	var side := clampi(int(round(bh * HEAD_RATIO)), 8, mini(w, h))
	# 水平中心取「人物顶部头带」的非透明像素中心，避免手臂/武器把整体 bbox 中心拉偏。
	var head_band := maxi(6, int(round(bh * 0.35)))
	var hmin := w
	var hmax := -1
	for y in range(miny, mini(miny + head_band, h)):
		for x in range(w):
			if img.get_pixel(x, y).a >= ALPHA_CUT:
				hmin = mini(hmin, x)
				hmax = maxi(hmax, x)
	var head_cx := (hmin + hmax) / 2 if hmax >= 0 else (minx + maxx) / 2
	var sx := clampi(head_cx - side / 2, 0, w - side)
	var sy := clampi(miny, 0, maxi(0, h - side))
	var thumb := img.get_region(Rect2i(sx, sy, side, side))
	thumb.resize(THUMB, THUMB, Image.INTERPOLATE_NEAREST)

	var out := ProjectSettings.globalize_path("%s%s/%s_portrait.png" % [DST, id, id])
	var err := thumb.save_png(out)
	print("[thumb] %s: 立绘 %dx%d bbox(%dx%d) headCx=%d → 裁 %dpx 方形 (err=%d)" % [id, w, h, bw, bh, head_cx, side, err])
	return err == OK


## 回填英雄 .tres 的 portrait_path + sprite_frames_path。
func _update_v4_tres(id: String) -> bool:
	var path := "%s%s.tres" % [HERO_DATA, id]
	if not ResourceLoader.exists(path):
		push_warning("%s: v4 .tres 不存在，跳过回填 %s" % [id, path])
		return true  # 不阻塞（h14-h17 v4 数据可能尚未生成）
	var hero: HeroData = load(path)
	if hero == null:
		push_error("%s: v4 .tres 加载失败" % id)
		return false
	hero.portrait_path = "%s%s/%s_portrait.png" % [DST, id, id]
	hero.sprite_frames_path = "%s%s/%s_idle.tres" % [DST, id, id]
	var err := ResourceSaver.save(hero, path)
	print("[v4tres] %s: 回填 portrait + sprite_frames (err=%d)" % [id, err])
	return err == OK


## 该 256 格是否全透明（采样步长 8 加速）。
func _cell_empty(img: Image, x: int, y: int) -> bool:
	var step := 8
	var h := img.get_height()
	var w := img.get_width()
	for yy in range(y, mini(y + CELL, h), step):
		for xx in range(x, mini(x + CELL, w), step):
			if img.get_pixel(xx, yy).a > 0.15:
				return false
	return true
